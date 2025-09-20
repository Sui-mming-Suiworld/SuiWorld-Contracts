from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Iterable, List, Sequence

from ..schemas import MessageCreator, MessageFeedEntry, MessageMetrics, MessageStatus

LIKES_THRESHOLD = 20
ALERTS_THRESHOLD = 20


@dataclass(frozen=True)
class MessageSeed:
    id: str
    gallery_slug: str
    title: str
    content: str
    tags: Sequence[str]
    creator_id: str
    creator_handle: str
    creator_display_name: str
    creator_avatar_url: str
    likes: int
    alerts: int
    status: MessageStatus
    created_at: datetime
    updated_at: datetime


MESSAGE_SEEDS: Sequence[MessageSeed] = (
    MessageSeed(
        id="msg-001",
        gallery_slug="degen",
        title="Restaking flywheel on Sui",
        content=(
            "Capturing Sui LST flow by restaking LP receipts into cross-chain credit pools. "
            "Managers are asking for a dry run before going mainnet."
        ),
        tags=("restaking", "defi", "strategy"),
        creator_id="user-alba",
        creator_handle="@alba",
        creator_display_name="Alba Research",
        creator_avatar_url="https://cdn.suiworld.xyz/avatars/alba.png",
        likes=19,
        alerts=1,
        status=MessageStatus.NORMAL,
        created_at=datetime(2024, 9, 12, 8, 30, tzinfo=timezone.utc),
        updated_at=datetime(2024, 9, 12, 12, 5, tzinfo=timezone.utc),
    ),
    MessageSeed(
        id="msg-002",
        gallery_slug="degen",
        title="ZK rollup gas rebates",
        content=(
            "Team proposing to redirect 40% of the foundation rebate into an automation vault."
        ),
        tags=("zk", "governance"),
        creator_id="user-mira",
        creator_handle="@mira",
        creator_display_name="Mira",
        creator_avatar_url="https://cdn.suiworld.xyz/avatars/mira.png",
        likes=27,
        alerts=3,
        status=MessageStatus.NORMAL,
        created_at=datetime(2024, 9, 11, 16, 10, tzinfo=timezone.utc),
        updated_at=datetime(2024, 9, 12, 9, 42, tzinfo=timezone.utc),
    ),
    MessageSeed(
        id="msg-003",
        gallery_slug="degen",
        title="Suspicious volume spike",
        content=(
            "Spotting recycled liquidity moving between two burner wallets. Requesting manager eyes."
        ),
        tags=("surveillance", "risk"),
        creator_id="user-hank",
        creator_handle="@hank",
        creator_display_name="Hank",
        creator_avatar_url="https://cdn.suiworld.xyz/avatars/hank.png",
        likes=8,
        alerts=24,
        status=MessageStatus.NORMAL,
        created_at=datetime(2024, 9, 10, 20, 55, tzinfo=timezone.utc),
        updated_at=datetime(2024, 9, 12, 7, 13, tzinfo=timezone.utc),
    ),
    MessageSeed(
        id="msg-004",
        gallery_slug="dev",
        title="Validator telemetry overhaul",
        content=(
            "Shipping a CLI for managers to export gossip metrics into Prometheus through an agent."
        ),
        tags=("infra", "devops"),
        creator_id="user-sol",
        creator_handle="@sol",
        creator_display_name="Sol",
        creator_avatar_url="https://cdn.suiworld.xyz/avatars/sol.png",
        likes=12,
        alerts=0,
        status=MessageStatus.HYPED,
        created_at=datetime(2024, 9, 9, 14, 20, tzinfo=timezone.utc),
        updated_at=datetime(2024, 9, 11, 5, 2, tzinfo=timezone.utc),
    ),
)


def _status_reason(seed: MessageSeed) -> str | None:
    if seed.status is not MessageStatus.NORMAL:
        return None
    if seed.likes >= LIKES_THRESHOLD:
        return "likes_threshold"
    if seed.alerts >= ALERTS_THRESHOLD:
        return "alerts_threshold"
    return None


def _display_status(seed: MessageSeed) -> MessageStatus:
    if seed.status is not MessageStatus.NORMAL:
        return seed.status
    if seed.likes >= LIKES_THRESHOLD or seed.alerts >= ALERTS_THRESHOLD:
        return MessageStatus.UNDER_REVIEW
    return seed.status


def _likes_to_threshold(seed: MessageSeed) -> int | None:
    if seed.status is not MessageStatus.NORMAL:
        return None
    if seed.likes >= LIKES_THRESHOLD:
        return 0
    return LIKES_THRESHOLD - seed.likes


def _alerts_to_threshold(seed: MessageSeed) -> int | None:
    if seed.status is not MessageStatus.NORMAL:
        return None
    if seed.alerts >= ALERTS_THRESHOLD:
        return 0
    return ALERTS_THRESHOLD - seed.alerts


def _build_entry(seed: MessageSeed) -> MessageFeedEntry:
    status_reason = _status_reason(seed)
    return MessageFeedEntry(
        id=seed.id,
        gallery_slug=seed.gallery_slug,
        title=seed.title,
        content=seed.content,
        tags=list(seed.tags),
        created_at=seed.created_at,
        updated_at=seed.updated_at,
        creator=MessageCreator(
            id=seed.creator_id,
            handle=seed.creator_handle,
            display_name=seed.creator_display_name,
            avatar_url=seed.creator_avatar_url,
        ),
        metrics=MessageMetrics(
            likes=seed.likes,
            alerts=seed.alerts,
            base_status=seed.status,
            displayed_status=_display_status(seed),
            status_reason=status_reason,
            likes_to_threshold=_likes_to_threshold(seed),
            alerts_to_threshold=_alerts_to_threshold(seed),
        ),
    )


def _matches_search(seed: MessageSeed, term: str) -> bool:
    lowered = term.lower()
    return any(
        lowered in candidate
        for candidate in (
            seed.title.lower(),
            seed.content.lower(),
            seed.creator_handle.lower(),
            seed.creator_display_name.lower(),
        )
    ) or any(lowered in tag.lower() for tag in seed.tags)


def _tags_match(seed_tags: Sequence[str], required: Sequence[str], mode: str) -> bool:
    seed_lower = {tag.lower() for tag in seed_tags}
    required_lower = [tag.lower() for tag in required]
    if mode == "and":
        return all(tag in seed_lower for tag in required_lower)
    return any(tag in seed_lower for tag in required_lower)


def _sort_entries(entries: Iterable[MessageSeed], sort: str) -> List[MessageSeed]:
    if sort == "likes":
        return sorted(entries, key=lambda seed: (seed.likes, seed.created_at), reverse=True)
    if sort == "alerts":
        return sorted(entries, key=lambda seed: (seed.alerts, seed.created_at), reverse=True)
    if sort == "under_review":
        return sorted(
            entries,
            key=lambda seed: (
                1 if _display_status(seed) is MessageStatus.UNDER_REVIEW else 0,
                seed.likes,
                seed.created_at,
            ),
            reverse=True,
        )
    return sorted(entries, key=lambda seed: seed.created_at, reverse=True)


def list_messages(
    gallery_slug: str,
    *,
    search: str | None = None,
    tags: Sequence[str] | None = None,
    tag_mode: str = "or",
    sort: str = "latest",
) -> List[MessageFeedEntry]:
    normalized_gallery = gallery_slug.lower().strip()
    if not normalized_gallery:
        return []

    seeds = [seed for seed in MESSAGE_SEEDS if seed.gallery_slug == normalized_gallery]
    if not seeds:
        return []

    if search:
        seeds = [seed for seed in seeds if _matches_search(seed, search)]

    if tags:
        mode = (tag_mode or "or").lower()
        if mode not in {"or", "and"}:
            mode = "or"
        seeds = [seed for seed in seeds if _tags_match(seed.tags, tags, mode)]

    sort_value = (sort or "latest").lower()
    seeds = _sort_entries(seeds, sort_value)
    return [_build_entry(seed) for seed in seeds]
