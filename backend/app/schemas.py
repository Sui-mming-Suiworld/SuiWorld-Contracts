from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field


class ZkLoginProof(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    proof: Dict[str, Any] = Field(..., description="zkLogin proof payload")
    public_inputs: Optional[List[str]] = Field(
        default=None,
        alias="publicInputs",
        description="Public inputs supplied alongside the proof",
    )
    max_epoch: Optional[int] = Field(
        default=None,
        alias="maxEpoch",
        description="Upper bound epoch for which the proof is valid",
    )
    jwt_randomness: Optional[str] = Field(
        default=None,
        alias="jwtRandomness",
        description="Randomness that was used when creating the proof JWT",
    )


class ZkLoginRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    provider: str = Field(..., description="OIDC provider used for zkLogin")
    jwt: str = Field(..., description="OIDC ID token that accompanies the zkLogin proof")
    nonce: str = Field(..., description="Nonce provided to the OIDC provider")
    sui_address: str = Field(..., alias="suiAddress", description="Derived Sui address")
    session_key: str = Field(
        ..., alias="sessionKey", description="Ephemeral public key bound to the session"
    )
    signature: str = Field(..., description="Signature proving control of the session key")
    proof: ZkLoginProof


class SupabaseLoginRequest(BaseModel):
    access_token: str = Field(..., description="Supabase access token returned by OAuth")


class AuthSession(BaseModel):
    token: str = Field(..., description="Backend issued session token")
    expires_at: datetime = Field(..., description="Expiration timestamp for the backend session")


class UserProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: Optional[int] = Field(default=None, description="Internal numeric identifier")
    supabase_id: Optional[str] = Field(
        default=None, description="Supabase auth identifier for this user"
    )
    email: Optional[str] = Field(default=None, description="User email address")
    sui_address: Optional[str] = Field(default=None, description="Linked Sui address")
    session_key: Optional[str] = Field(
        default=None, description="Latest ephemeral session key for zkLogin"
    )


class SupabaseLoginResponse(BaseModel):
    profile: UserProfileRead
    session: AuthSession


class ZkLoginResponse(BaseModel):
    profile: UserProfileRead
    session: AuthSession


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
    title: str
    content: str
    tags: List[str]
    created_at: datetime
    updated_at: datetime
    creator: MessageCreator
    metrics: MessageMetrics


class MessageCreate(BaseModel):
    content: str


class MessageRead(BaseModel):
    id: int
    content: str
    like_count: int
    alert_count: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
