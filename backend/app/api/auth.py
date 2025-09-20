from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import UserProfile
from ..schemas import (
    AuthSession,
    SupabaseLoginRequest,
    SupabaseLoginResponse,
    UserProfileRead,
    ZkLoginRequest,
    ZkLoginResponse,
)
from ..security import create_session_token, verify_supabase_jwt

router = APIRouter()


async def _fetch_supabase_user(access_token: str) -> Dict[str, Any]:
    url = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/user"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(url, headers=headers)
        if response.status_code == status.HTTP_200_OK:
            return response.json()

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Supabase access token is invalid or expired",
    )


def _upsert_profile(
    db: Session,
    *,
    supabase_id: Optional[str],
    email: Optional[str],
    sui_address: Optional[str],
    session_key: Optional[str],
) -> UserProfile:
    profile: Optional[UserProfile] = None

    if supabase_id:
        profile = db.query(UserProfile).filter(UserProfile.supabase_id == supabase_id).one_or_none()

    if profile is None and sui_address:
        profile = db.query(UserProfile).filter(UserProfile.sui_address == sui_address).one_or_none()

    if profile is None:
        profile = UserProfile(
            supabase_id=supabase_id,
            email=email,
            sui_address=sui_address,
            session_key=session_key,
        )
        db.add(profile)
    else:
        if supabase_id and profile.supabase_id != supabase_id:
            profile.supabase_id = supabase_id
        if email and profile.email != email:
            profile.email = email
        if sui_address and profile.sui_address != sui_address:
            profile.sui_address = sui_address
        if session_key and profile.session_key != session_key:
            profile.session_key = session_key

    db.commit()
    db.refresh(profile)
    return profile


@router.post("/supabase-login", response_model=SupabaseLoginResponse)
async def supabase_login(payload: SupabaseLoginRequest, db: Session = Depends(get_db)):
    claims = await verify_supabase_jwt(payload.access_token)
    supabase_user = await _fetch_supabase_user(payload.access_token)

    supabase_id = str(claims.get("sub"))
    email = supabase_user.get("email") or claims.get("email")

    profile = _upsert_profile(
        db,
        supabase_id=supabase_id,
        email=email,
        sui_address=None,
        session_key=None,
    )

    token, expires_at = create_session_token(
        subject=supabase_id,
        provider="supabase",
        extra_claims={"profile_id": profile.id},
    )

    return SupabaseLoginResponse(
        profile=UserProfileRead.model_validate(profile),
        session=AuthSession(token=token, expires_at=expires_at),
    )


def _decode_zklogin_jwt(token: str) -> Dict[str, Any]:
    public_key = settings.ZKLOGIN_JWT_PUBLIC_KEY
    options: Dict[str, Any] = {"verify_signature": bool(public_key)}
    if public_key:
        try:
            return jwt.decode(
                token,
                public_key,
                algorithms=["RS256"],
                options=options,
                audience=settings.ZKLOGIN_JWT_AUDIENCE,
                issuer=settings.ZKLOGIN_JWT_ISSUER,
            )
        except JWTError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid zkLogin token: {exc}",
            ) from exc

    return jwt.get_unverified_claims(token)


@router.post("/zk-login", response_model=ZkLoginResponse)
async def zk_login(payload: ZkLoginRequest, db: Session = Depends(get_db)):
    claims = _decode_zklogin_jwt(payload.jwt)
    now = datetime.now(timezone.utc)

    exp_timestamp = claims.get("exp")
    if exp_timestamp is not None:
        exp_dt = datetime.fromtimestamp(exp_timestamp, tz=timezone.utc)
        if exp_dt <= now:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="OIDC token has expired",
            )
    else:
        exp_dt = now

    nonce_claim = claims.get("nonce")
    if nonce_claim != payload.nonce:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nonce mismatch between proof and OIDC token",
        )

    profile = _upsert_profile(
        db,
        supabase_id=None,
        email=claims.get("email"),
        sui_address=payload.sui_address,
        session_key=payload.session_key,
    )

    subject = profile.sui_address or str(profile.id)
    token, expires_at = create_session_token(
        subject=subject,
        provider=payload.provider,
        session_key=payload.session_key,
        extra_claims={"profile_id": profile.id},
    )

    return ZkLoginResponse(
        profile=UserProfileRead.model_validate(profile),
        session=AuthSession(token=token, expires_at=expires_at),
    )
