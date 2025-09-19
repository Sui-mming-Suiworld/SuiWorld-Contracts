from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def get_proposals():
    # TODO: Get active hype/scam proposals for managers
    return []

@router.post("/{proposal_id}/vote")
def vote_on_proposal(proposal_id: int):
    # TODO: Allow managers to vote (2/3 majority)
    # On success, resolve hype/scam via chain.py
    return {"status": "voted"}
