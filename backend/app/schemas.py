# TODO: Define Pydantic schemas for API request/response validation
from pydantic import BaseModel

class MessageCreate(BaseModel):
    content: str
    gallery_slug: str

class UserProfile(BaseModel):
    id: str
    image_url: str
    description: str
