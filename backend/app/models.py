from __future__ import annotations

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func

Base = declarative_base()


class TimestampMixin:
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.timezone("utc", func.now()),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.timezone("utc", func.now()),
        onupdate=func.timezone("utc", func.now()),
        nullable=False,
    )


class UserProfile(Base):
    __tablename__ = "profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, nullable=False)
    supabase_id = Column(String, unique=True, nullable=True)
    email = Column(String, unique=True, nullable=True)
    sui_address = Column(String, unique=True, nullable=True)
    display_name = Column(Text, nullable=True)
    avatar_url = Column(Text, nullable=True)
    bio = Column(Text, nullable=True)
    session_key = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.timezone("utc", func.now()),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.timezone("utc", func.now()),
        onupdate=func.timezone("utc", func.now()),
        nullable=False,
    )


class Message(TimestampMixin, Base):
    __tablename__ = "messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    author_profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    title = Column(Text, nullable=False)
    body_text = Column(Text, nullable=True)
    body_url = Column(Text, nullable=True)
    body_hash = Column(Text, nullable=True)
    tags = Column(ARRAY(String), nullable=False, server_default="{}")
    state = Column(Text, nullable=False, server_default="NORMAL")
    likes_count = Column(Integer, nullable=False, server_default="0")
    alerts_count = Column(Integer, nullable=False, server_default="0")
    anchor_tx_digest = Column(Text, nullable=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True)


class Comment(TimestampMixin, Base):
    __tablename__ = "comments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    message_id = Column(UUID(as_uuid=True), ForeignKey("messages.id"))
    author_profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    body_text = Column(Text, nullable=False)
    likes_count = Column(Integer, nullable=False, server_default="0")
    deleted_at = Column(DateTime(timezone=True), nullable=True)


class CommentLike(Base):
    __tablename__ = "comment_likes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    comment_id = Column(UUID(as_uuid=True), ForeignKey("comments.id"))
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ManagerNFTLedger(Base):
    __tablename__ = "manager_nft_ledger"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    owner_profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    nft_object_id = Column(Text, nullable=False)
    active = Column(Boolean, nullable=False, server_default="true")
    minted_at = Column(DateTime(timezone=True), server_default=func.now())
    burned_at = Column(DateTime(timezone=True), nullable=True)
    burn_reason = Column(Text, nullable=True)


class MessageAlert(Base):
    __tablename__ = "message_alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    message_id = Column(UUID(as_uuid=True), ForeignKey("messages.id"))
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    reason = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class MessageLike(Base):
    __tablename__ = "message_likes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    message_id = Column(UUID(as_uuid=True), ForeignKey("messages.id"))
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class MessageMedia(Base):
    __tablename__ = "message_media"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    message_id = Column(UUID(as_uuid=True), ForeignKey("messages.id"))
    url = Column(Text, nullable=False)
    mime = Column(Text, nullable=True)
    size_bytes = Column(Integer, nullable=True)
    hash = Column(Text, nullable=True)


class Proposal(Base):
    __tablename__ = "proposals"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    message_id = Column(UUID(as_uuid=True), ForeignKey("messages.id"))
    kind = Column(Text, nullable=False)
    trigger_by = Column(Text, nullable=False)
    status = Column(Text, nullable=False, server_default="OPEN")
    required_agree = Column(Integer, nullable=False, server_default="4")
    total_managers = Column(Integer, nullable=False, server_default="12")
    snapshot_likes = Column(Integer, nullable=False, server_default="0")
    snapshot_alerts = Column(Integer, nullable=False, server_default="0")
    opened_by_system = Column(Boolean, server_default="true")
    opened_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)


class Payout(Base):
    __tablename__ = "payouts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    proposal_id = Column(UUID(as_uuid=True), ForeignKey("proposals.id"))
    recipient_profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    kind = Column(Text, nullable=False)
    amount_swt = Column(Integer, nullable=False)
    tx_digest = Column(Text, nullable=True)
    status = Column(Text, nullable=False, server_default="PENDING")
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Swap(Base):
    __tablename__ = "swaps"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    direction = Column(Text, nullable=False)
    amount_in = Column(Numeric, nullable=False)
    amount_out = Column(Numeric, nullable=False)
    price = Column(Numeric, nullable=False)
    tx_digest = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class TxLog(Base):
    __tablename__ = "tx_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    kind = Column(Text, nullable=False)
    target_addr = Column(Text, nullable=True)
    amount = Column(Numeric, nullable=True)
    payload_json = Column(JSONB, nullable=True)
    tx_digest = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Vote(Base):
    __tablename__ = "votes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=func.uuid_generate_v4())
    proposal_id = Column(UUID(as_uuid=True), ForeignKey("proposals.id"))
    voter_profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id"))
    support = Column(Boolean, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
