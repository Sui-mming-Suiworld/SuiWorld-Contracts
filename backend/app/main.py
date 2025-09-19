from fastapi import FastAPI
from .api import auth, galleries, messages, reactions, proposals, swap

app = FastAPI(title="SuiWorld Backend")

# TODO: Add middleware for logging, auth, etc.

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(galleries.router, prefix="/galleries", tags=["galleries"])
app.include_router(messages.router, prefix="/messages", tags=["messages"])
app.include_router(reactions.router, prefix="/reactions", tags=["reactions"])
app.include_router(proposals.router, prefix="/proposals", tags=["proposals"])
app.include_router(swap.router, prefix="/swap", tags=["swap"])

@app.get("/")
def read_root():
    return {"status": "ok"}
