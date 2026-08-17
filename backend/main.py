from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
import bcrypt
import random, string

from database import engine, get_db, Base
import models, schemas, detection

Base.metadata.create_all(bind=engine)

app = FastAPI(title="SafeGuard API")


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))

def make_pairing_code(n=6):
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=n))


@app.get("/")
def home():
    return {"status": "SafeGuard backend running"}


@app.post("/parents/register", response_model=schemas.ParentOut)
def register(data: schemas.ParentCreate, db: Session = Depends(get_db)):
    existing = db.query(models.Parent).filter(models.Parent.email == data.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    parent = models.Parent(
        full_name=data.full_name,
        email=data.email,
        password_hash=hash_password(data.password),
    )
    db.add(parent)
    db.commit()
    db.refresh(parent)
    return parent


@app.post("/parents/login", response_model=schemas.ParentOut)
def login(data: schemas.ParentLogin, db: Session = Depends(get_db)):
    parent = db.query(models.Parent).filter(models.Parent.email == data.email).first()
    if not parent or not verify_password(data.password, parent.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return parent


@app.post("/parents/{parent_id}/children", response_model=schemas.ChildOut)
def add_child(parent_id: str, data: schemas.ChildCreate, db: Session = Depends(get_db)):
    parent = db.query(models.Parent).filter(models.Parent.id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Parent not found")
    child = models.Child(
        parent_id=parent_id,
        name=data.name,
        age=data.age,
        pairing_code=make_pairing_code(),
    )
    db.add(child)
    db.commit()
    db.refresh(child)
    settings = models.MonitoringSettings(child_id=child.id)
    db.add(settings)
    db.commit()
    return child


@app.get("/parents/{parent_id}/children", response_model=list[schemas.ChildOut])
def list_children(parent_id: str, db: Session = Depends(get_db)):
    return db.query(models.Child).filter(models.Child.parent_id == parent_id).all()


@app.get("/children/{child_id}/settings", response_model=schemas.SettingsOut)
def get_settings(child_id: str, db: Session = Depends(get_db)):
    s = db.query(models.MonitoringSettings).filter(models.MonitoringSettings.child_id == child_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Settings not found")
    return s


@app.patch("/children/{child_id}/settings", response_model=schemas.SettingsOut)
def update_settings(child_id: str, data: schemas.SettingsUpdate, db: Session = Depends(get_db)):
    s = db.query(models.MonitoringSettings).filter(models.MonitoringSettings.child_id == child_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Settings not found")
    for field, value in data.dict(exclude_unset=True).items():
        setattr(s, field, value)
    db.commit()
    db.refresh(s)
    return s


@app.post("/events", response_model=schemas.EventOut)
def create_event(data: schemas.EventCreate, db: Session = Depends(get_db)):
    child = db.query(models.Child).filter(models.Child.id == data.child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")
    event = models.Event(
        child_id=data.child_id,
        type=data.type,
        content=data.content,
        detected_language=data.detected_language,
        severity=data.severity or "low",
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


@app.get("/children/{child_id}/events", response_model=list[schemas.EventOut])
def list_events(child_id: str, db: Session = Depends(get_db)):
    return db.query(models.Event).filter(models.Event.child_id == child_id).order_by(models.Event.created_at.desc()).all()

# ---------- DETECTION: analyze captured text ----------
@app.post("/children/{child_id}/analyze")
def analyze_text(child_id: str, payload: dict, db: Session = Depends(get_db)):
    """
    Receives captured text (from chat, notification listener, or OCR),
    runs Layer 1 detection, and auto-creates an event if flagged.
    Body: { "text": "the message to check", "source": "chat|notification|ocr" }
    """
    child = db.query(models.Child).filter(models.Child.id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    text = payload.get("text", "")
    source = payload.get("source", "unknown")

    # check this child's settings - only run if the feature is enabled
    settings = db.query(models.MonitoringSettings).filter(
        models.MonitoringSettings.child_id == child_id
    ).first()

    result = detection.detect_language_layer1(text)

    created_events = []

    # language event
    if result["is_offensive"] and (not settings or settings.language_enabled):
        event = models.Event(
            child_id=child_id,
            type="language",
            content=f"[{source}] {text}",
            detected_language="derja/mixed",
            severity=result["severity"] or "low",
        )
        db.add(event)
        created_events.append("language")

    # bullying event
    if result["is_bullying"] and (not settings or settings.bullying_enabled):
        event = models.Event(
            child_id=child_id,
            type="bullying",
            content=f"[{source}] {text}",
            detected_language="derja/mixed",
            severity="medium",
        )
        db.add(event)
        created_events.append("bullying")

    db.commit()

    return {
        "analyzed": text,
        "result": result,
        "events_created": created_events,
    }
