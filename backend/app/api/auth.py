from __future__ import annotations

import hashlib
import uuid
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


def _derive_sui_address(*, sub: str, issuer: Optional[str], email: Optional[str]) -> str:
    salt = settings.SUPABASE_ADDRESS_SALT
    components = [salt, issuer or "", sub, email or ""]
    material = "::".join(components)
    digest = hashlib.sha256(material.encode("utf-8")).hexdigest()
    return "0x" + digest[:64]


async def _fetch_supabase_user(access_token: str) -> Dict[str, Any]:
    url = f"{str(settings.SUPABASE_URL).rstrip('/')}/auth/v1/user"
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
    display_name: Optional[str],
    avatar_url: Optional[str],
    session_key: Optional[str],
) -> UserProfile:
    profile: Optional[UserProfile] = None
    supabase_uuid: Optional[uuid.UUID] = None

    if supabase_id:
        try:
            supabase_uuid = uuid.UUID(supabase_id)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid Supabase user id",
            ) from exc

        profile = db.query(UserProfile).filter(UserProfile.id == supabase_uuid).one_or_none()

    if profile is None and sui_address:
        profile = db.query(UserProfile).filter(UserProfile.sui_address == sui_address).one_or_none()

    if profile is None:
        profile = UserProfile(
            id=supabase_uuid,
            supabase_id=supabase_id,
            email=email,
            sui_address=sui_address,
            display_name=display_name,
            avatar_url=avatar_url,
            session_key=session_key,
        )
        db.add(profile)
    else:
        if supabase_uuid and profile.id != supabase_uuid:
            profile.id = supabase_uuid
        if supabase_id and profile.supabase_id != supabase_id:
            profile.supabase_id = supabase_id
        if email and profile.email != email:
            profile.email = email
        if sui_address and profile.sui_address != sui_address:
            profile.sui_address = sui_address
        if display_name is not None and profile.display_name != display_name:
            profile.display_name = display_name
        if avatar_url is not None and profile.avatar_url != avatar_url:
            profile.avatar_url = avatar_url
        if session_key and profile.session_key != session_key:
            profile.session_key = session_key

    db.commit()
    db.refresh(profile)
    return profile


@router.post("/supabase-login", response_model=SupabaseLoginResponse)
async def supabase_login(payload: SupabaseLoginRequest, db: Session = Depends(get_db)):
    claims = await verify_supabase_jwt(payload.access_token)
    supabase_user = await _fetch_supabase_user(payload.access_token)

    supabase_id = str(supabase_user.get("id") or claims.get("sub"))
    if not supabase_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Supabase user id missing")

    issuer = claims.get("iss") or settings.supabase_issuer()
    email = supabase_user.get("email") or claims.get("email")
    user_metadata = supabase_user.get("user_metadata") or {}
    display_name = user_metadata.get("full_name") or user_metadata.get("name")
    avatar_url = user_metadata.get("avatar_url") or user_metadata.get("picture")

    try:
        sui_address = _derive_sui_address(sub=supabase_id, issuer=issuer, email=email)
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc

    profile = _upsert_profile(
        db,
        supabase_id=supabase_id,
        email=email,
        sui_address=sui_address,
        display_name=display_name,
        avatar_url=avatar_url,
        session_key=None,
    )

    token, expires_at = create_session_token(
        subject=supabase_id,
        provider="supabase",
        extra_claims={"profile_id": str(profile.id)},
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
        display_name=claims.get("name"),
        avatar_url=claims.get("picture"),
        session_key=payload.session_key,
    )

    subject = profile.sui_address or str(profile.id)
    token, expires_at = create_session_token(
        subject=subject,
        provider=payload.provider,
        session_key=payload.session_key,
        extra_claims={"profile_id": str(profile.id)},
    )

    return ZkLoginResponse(
        profile=UserProfileRead.model_validate(profile),
        session=AuthSession(token=token, expires_at=expires_at),
    )
