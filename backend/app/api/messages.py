from typing import List, Optional

from fastapi import APIRouter, Query

from ..schemas import MessageFeedEntry
from ..services.messages import list_messages

router = APIRouter()


@router.get("/", response_model=List[MessageFeedEntry])
def get_messages(
    search: Optional[str] = Query(
        default=None,
        description="Case-insensitive search across title, content, creator handle, and tags.",
    ),
    tags: Optional[List[str]] = Query(
        default=None,
        description="Filter messages by tag labels. Provide multiple tag values to include more options.",
    ),
    tag_mode: str = Query(
        default="or",
        description="How to apply provided tag filters: 'or' (default) or 'and'.",
    ),
    sort: str = Query(
        default="latest",
        description="Sort mode: 'latest', 'likes', 'alerts', or 'under_review'.",
    ),
) -> List[MessageFeedEntry]:
    messages = list_messages(
        search=search,
        tags=tags,
        tag_mode=tag_mode,
        sort=sort,
    )
    return messages


@router.post("/")
def create_message():
    # TODO: Implement message creation (requires >= 1000 SWT)
    return {"status": "created"}


@router.put("/{message_id}")
def update_message(message_id: int):
    # TODO: Implement message update (requires >= 1000 SWT or Manager NFT)
    return {"status": "updated"}


@router.delete("/{message_id}")
def delete_message(message_id: int):
    # TODO: Implement message deletion (requires Manager NFT)
    return {"status": "deleted"}
