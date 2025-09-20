from sqlalchemy import Column, DateTime, Integer, String, Text, func
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class TimestampMixin:
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class UserProfile(TimestampMixin, Base):
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True)
    supabase_id = Column(String(255), unique=True, index=True, nullable=True)
    email = Column(String(255), unique=True, nullable=True)
    sui_address = Column(String(255), unique=True, index=True, nullable=True)
    session_key = Column(Text, nullable=True)


class Message(TimestampMixin, Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True)
    content = Column(Text, nullable=False)
    like_count = Column(Integer, default=0, nullable=False)
    alert_count = Column(Integer, default=0, nullable=False)
