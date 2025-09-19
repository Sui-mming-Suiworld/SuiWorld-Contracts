from fastapi import APIRouter

router = APIRouter()

@router.post("/zk-login")
def zk_login():
    # TODO: Implement zkLogin wallet creation and session management
    return {"status": "ok"}
