from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
from uuid import UUID


# ---------- PARENT ----------
class ParentCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str

class ParentLogin(BaseModel):
    email: EmailStr
    password: str

class ParentOut(BaseModel):
    id: UUID
    full_name: str
    email: EmailStr
    created_at: datetime
    class Config:
        from_attributes = True


# ---------- CHILD ----------
class ChildCreate(BaseModel):
    name: str
    age: Optional[int] = None

class ChildOut(BaseModel):
    id: UUID
    name: str
    age: Optional[int]
    pairing_code: Optional[str]
    linked_at: Optional[datetime]
    created_at: datetime
    class Config:
        from_attributes = True


# ---------- MONITORING SETTINGS ----------
class SettingsUpdate(BaseModel):
    language_enabled: Optional[bool] = None
    language_sensitivity: Optional[str] = None
    image_enabled: Optional[bool] = None
    image_sensitivity: Optional[str] = None
    website_enabled: Optional[bool] = None
    duration_enabled: Optional[bool] = None
    duration_threshold: Optional[int] = None
    stranger_enabled: Optional[bool] = None
    bullying_enabled: Optional[bool] = None
    mental_health_enabled: Optional[bool] = None
    sos_enabled: Optional[bool] = None

class SettingsOut(BaseModel):
    child_id: UUID
    language_enabled: bool
    language_sensitivity: str
    image_enabled: bool
    image_sensitivity: str
    website_enabled: bool
    duration_enabled: bool
    duration_threshold: int
    stranger_enabled: bool
    bullying_enabled: bool
    mental_health_enabled: bool
    sos_enabled: bool
    class Config:
        from_attributes = True


# ---------- EVENT ----------
class EventCreate(BaseModel):
    child_id: UUID
    type: str
    content: Optional[str] = None
    detected_language: Optional[str] = None
    severity: Optional[str] = "low"

class EventOut(BaseModel):
    id: UUID
    child_id: UUID
    type: str
    content: Optional[str]
    detected_language: Optional[str]
    severity: str
    created_at: datetime
    class Config:
        from_attributes = True


# ---------- ALERT ----------
class AlertOut(BaseModel):
    id: UUID
    event_id: UUID
    message: str
    is_read: bool
    sent_at: datetime
    class Config:
        from_attributes = True
