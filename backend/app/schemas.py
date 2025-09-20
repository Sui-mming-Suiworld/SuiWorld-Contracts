from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel


class MessageStatus(str, Enum):
    NORMAL = "NORMAL"
    UNDER_REVIEW = "UNDER_REVIEW"
    HYPED = "HYPED"
    SPAM = "SPAM"
    DELETED = "DELETED"


class MessageCreator(BaseModel):
    id: str
    handle: str
    display_name: str
    avatar_url: str


class MessageMetrics(BaseModel):
    likes: int
    alerts: int
    base_status: MessageStatus
    displayed_status: MessageStatus
    status_reason: Optional[str] = None
    likes_to_threshold: Optional[int] = None
    alerts_to_threshold: Optional[int] = None


class MessageFeedEntry(BaseModel):
    id: str
    gallery_slug: str
    title: str
    content: str
    tags: List[str]
    created_at: datetime
    updated_at: datetime
    creator: MessageCreator
    metrics: MessageMetrics


class MessageCreate(BaseModel):
    content: str
    gallery_slug: str


class UserProfile(BaseModel):
    id: str
    image_url: str
    description: str
