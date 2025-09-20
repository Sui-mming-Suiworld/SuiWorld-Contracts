from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt, jwk
from jose.utils import base64url_decode

from .config import settings

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

_SUPABASE_JWKS_CACHE: Optional[Dict[str, Any]] = None
_SUPABASE_JWKS_EXPIRES_AT: Optional[datetime] = None


async def get_supabase_jwks() -> Dict[str, Any]:
    global _SUPABASE_JWKS_CACHE, _SUPABASE_JWKS_EXPIRES_AT

    now = datetime.now(timezone.utc)
    if _SUPABASE_JWKS_CACHE and _SUPABASE_JWKS_EXPIRES_AT and _SUPABASE_JWKS_EXPIRES_AT > now:
        return _SUPABASE_JWKS_CACHE

    jwks_url = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(jwks_url)
            response.raise_for_status()
            _SUPABASE_JWKS_CACHE = response.json()
            _SUPABASE_JWKS_EXPIRES_AT = now + timedelta(hours=1)
            return _SUPABASE_JWKS_CACHE
    except httpx.HTTPStatusError as exc:  # pragma: no cover - network errors during tests
        raise HTTPException(
            status_code=exc.response.status_code,
            detail=f"Failed to fetch Supabase JWKS: {exc.response.text}",
        )
    except httpx.RequestError as exc:  # pragma: no cover - network errors during tests
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Could not reach Supabase JWKS endpoint: {exc}",
        )


async def _supabase_key_for(token: str) -> Dict[str, Any]:
    jwks = await get_supabase_jwks()
    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")
    if not kid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="JWT missing kid header")

    for key in jwks.get("keys", []):
        if key.get("kid") == kid:
            return key

    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unable to find matching JWK")


async def verify_supabase_jwt(token: str) -> Dict[str, Any]:
    key_dict = await _supabase_key_for(token)

    message, encoded_signature = token.rsplit(".", 1)
    decoded_signature = base64url_decode(encoded_signature.encode("utf-8"))
    public_key = jwk.construct(key_dict, algorithm="RS256")

    if not public_key.verify(message.encode("utf-8"), decoded_signature):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Supabase signature")

    claims = jwt.get_unverified_claims(token)

    audience = claims.get("aud")
    expected_aud = settings.SUPABASE_JWT_AUDIENCE
    if expected_aud:
        if isinstance(audience, list):
            if expected_aud not in audience:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Audience mismatch")
        elif audience != expected_aud:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Audience mismatch")

    issuer = claims.get("iss")
    if issuer and issuer != settings.supabase_issuer():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Issuer mismatch")

    exp = claims.get("exp")
    if exp and datetime.fromtimestamp(exp, tz=timezone.utc) <= datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Supabase token expired")

    return claims


def create_session_token(
    *,
    subject: str,
    provider: str,
    session_key: Optional[str] = None,
    extra_claims: Optional[Dict[str, Any]] = None,
    expires_minutes: Optional[int] = None,
) -> tuple[str, datetime]:
    now = datetime.now(timezone.utc)
    ttl = expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    expires_at = now + timedelta(minutes=ttl)

    payload: Dict[str, Any] = {
        "sub": subject,
        "provider": provider,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    if session_key:
        payload["session_key"] = session_key
    if extra_claims:
        payload.update(extra_claims)

    token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return token, expires_at


def get_current_user(token: str = Depends(oauth2_scheme)) -> Dict[str, Any]:
    # Placeholder ? this will be replaced once full auth flow is finished.
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid access token")
