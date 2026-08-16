from sqlalchemy import (
    Column, String, Integer, Boolean, Text, ForeignKey, DateTime, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
from database import Base


class Parent(Base):
    __tablename__ = "parent"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name = Column(String(100), nullable=False)
    email = Column(String(150), nullable=False, unique=True)
    password_hash = Column(Text, nullable=False)
    fcm_token = Column(Text)
    created_at = Column(DateTime, server_default=func.now())

    children = relationship("Child", back_populates="parent", cascade="all, delete")
    alerts = relationship("Alert", back_populates="parent", cascade="all, delete")


class Child(Base):
    __tablename__ = "child"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    parent_id = Column(UUID(as_uuid=True), ForeignKey("parent.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=False)
    age = Column(Integer)
    device_id = Column(String(200))
    pairing_code = Column(String(20))
    linked_at = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())

    parent = relationship("Parent", back_populates="children")
    settings = relationship("MonitoringSettings", back_populates="child", uselist=False, cascade="all, delete")
    events = relationship("Event", back_populates="child", cascade="all, delete")
    contacts = relationship("Contact", back_populates="child", cascade="all, delete")
    usage_records = relationship("UsageRecord", back_populates="child", cascade="all, delete")


class MonitoringSettings(Base):
    __tablename__ = "monitoring_settings"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    child_id = Column(UUID(as_uuid=True), ForeignKey("child.id", ondelete="CASCADE"), nullable=False, unique=True)
    language_enabled = Column(Boolean, nullable=False, default=True)
    language_sensitivity = Column(String(10), nullable=False, default="medium")
    image_enabled = Column(Boolean, nullable=False, default=True)
    image_sensitivity = Column(String(10), nullable=False, default="medium")
    website_enabled = Column(Boolean, nullable=False, default=True)
    duration_enabled = Column(Boolean, nullable=False, default=True)
    duration_threshold = Column(Integer, nullable=False, default=3600)
    stranger_enabled = Column(Boolean, nullable=False, default=True)
    bullying_enabled = Column(Boolean, nullable=False, default=True)
    mental_health_enabled = Column(Boolean, nullable=False, default=True)
    sos_enabled = Column(Boolean, nullable=False, default=True)
    updated_at = Column(DateTime, server_default=func.now())

    child = relationship("Child", back_populates="settings")


class Event(Base):
    __tablename__ = "event"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    child_id = Column(UUID(as_uuid=True), ForeignKey("child.id", ondelete="CASCADE"), nullable=False)
    type = Column(String(30), nullable=False)
    content = Column(Text)
    detected_language = Column(String(20))
    severity = Column(String(10), nullable=False, default="low")
    created_at = Column(DateTime, server_default=func.now())

    child = relationship("Child", back_populates="events")
    alert = relationship("Alert", back_populates="event", uselist=False, cascade="all, delete")


class Alert(Base):
    __tablename__ = "alert"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_id = Column(UUID(as_uuid=True), ForeignKey("event.id", ondelete="CASCADE"), nullable=False, unique=True)
    parent_id = Column(UUID(as_uuid=True), ForeignKey("parent.id", ondelete="CASCADE"), nullable=False)
    message = Column(Text, nullable=False)
    is_read = Column(Boolean, nullable=False, default=False)
    sent_at = Column(DateTime, server_default=func.now())

    event = relationship("Event", back_populates="alert")
    parent = relationship("Parent", back_populates="alerts")


class Contact(Base):
    __tablename__ = "contact"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    child_id = Column(UUID(as_uuid=True), ForeignKey("child.id", ondelete="CASCADE"), nullable=False)
    contact_name = Column(String(150))
    contact_handle = Column(String(200))
    is_approved = Column(Boolean, nullable=False, default=False)
    is_stranger = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, server_default=func.now())

    child = relationship("Child", back_populates="contacts")


class UsageRecord(Base):
    __tablename__ = "usage_record"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    child_id = Column(UUID(as_uuid=True), ForeignKey("child.id", ondelete="CASCADE"), nullable=False)
    app_or_video = Column(String(200), nullable=False)
    duration_seconds = Column(Integer, nullable=False, default=0)
    recorded_at = Column(DateTime, server_default=func.now())

    child = relationship("Child", back_populates="usage_records")


class SupportResource(Base):
    __tablename__ = "support_resource"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    contact_info = Column(String(200))
    language = Column(String(20), nullable=False, default="french")
