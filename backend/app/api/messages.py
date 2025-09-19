from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def get_messages(gallery_slug: str):
    # TODO: Return messages for a gallery
    return []

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
