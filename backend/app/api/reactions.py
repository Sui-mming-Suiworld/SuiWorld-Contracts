from fastapi import APIRouter

router = APIRouter()

@router.post("/{message_id}/like")
def like_message(message_id: int):
    # TODO: Increment off-chain like count
    # If > 20, trigger manager vote for hype
    return {"status": "ok"}

@router.post("/{message_id}/alert")
def alert_message(message_id: int):
    # TODO: Increment off-chain alert count
    # If > 20, trigger manager vote for scam
    return {"status": "ok"}
