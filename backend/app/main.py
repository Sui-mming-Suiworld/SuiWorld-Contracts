from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import auth, galleries, messages, proposals, reactions, swap, wallet
from .config import settings
from .db import engine
from .models import Base


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database state on startup."""
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="SuiWorld Backend", lifespan=lifespan)

allowed_origins = getattr(settings, "ALLOWED_ORIGINS", ["http://localhost:3000"])
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(galleries.router, prefix="/galleries", tags=["galleries"])
app.include_router(messages.router, prefix="/messages", tags=["messages"])
app.include_router(reactions.router, prefix="/reactions", tags=["reactions"])
app.include_router(proposals.router, prefix="/proposals", tags=["proposals"])
app.include_router(swap.router, prefix="/swap", tags=["swap"])
app.include_router(wallet.router, tags=["wallet"])
app.add_exception_handler(wallet.WalletAPIError, wallet.wallet_exception_handler)



@app.get("/")
def read_root():
    return {"status": "ok"}

