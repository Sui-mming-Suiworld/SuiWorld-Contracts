from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

from .config import settings

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

_SUPABASE_JWKS_CACHE: Optional[Dict[str, Any]] = None
_SUPABASE_JWKS_EXPIRES_AT: Optional[datetime] = None
_SUPABASE_KID_MAP: Dict[str, Dict[str, Any]] = {}


async def _refresh_jwks() -> Dict[str, Any]:
    jwks_url = f"{str(settings.SUPABASE_URL).rstrip('/')}/auth/v1/.well-known/jwks.json"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(jwks_url)
            response.raise_for_status()
            jwks = response.json()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=exc.response.status_code,
            detail=f"Failed to fetch Supabase JWKS: {exc.response.text}",
        )
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Could not reach Supabase JWKS endpoint: {exc}",
        )

    _SUPABASE_KID_MAP.clear()
    for key in jwks.get("keys", []):
        kid = key.get("kid")
        if kid:
            _SUPABASE_KID_MAP[kid] = key

    global _SUPABASE_JWKS_CACHE, _SUPABASE_JWKS_EXPIRES_AT
    _SUPABASE_JWKS_CACHE = jwks
    _SUPABASE_JWKS_EXPIRES_AT = datetime.now(timezone.utc) + timedelta(hours=1)
    return jwks


async def _get_jwks() -> Dict[str, Any]:
    now = datetime.now(timezone.utc)
    if _SUPABASE_JWKS_CACHE and _SUPABASE_JWKS_EXPIRES_AT and _SUPABASE_JWKS_EXPIRES_AT > now:
        return _SUPABASE_JWKS_CACHE
    return await _refresh_jwks()


async def _supabase_key_for(token: str) -> Optional[Dict[str, Any]]:
    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")
    if not kid:
        return None

    if kid in _SUPABASE_KID_MAP:
        return _SUPABASE_KID_MAP[kid]

    jwks = await _refresh_jwks()
    return jwks.get("keys", []) and _SUPABASE_KID_MAP.get(kid)


async def verify_supabase_jwt(token: str) -> Dict[str, Any]:
    header = jwt.get_unverified_header(token)
    algorithm = header.get("alg")

    if algorithm == "HS256":
        try:
            claims = jwt.decode(
                token,
                settings.SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                audience=settings.SUPABASE_JWT_AUDIENCE,
                issuer=settings.supabase_issuer(),
            )
        except JWTError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid Supabase signature: {exc}",
            ) from exc
    else:
        key_dict = await _supabase_key_for(token)
        if not key_dict:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unable to find matching JWK")

        try:
            claims = jwt.decode(
                token,
                key_dict,
                algorithms=[algorithm] if algorithm else ["RS256"],
                audience=settings.SUPABASE_JWT_AUDIENCE,
                issuer=settings.supabase_issuer(),
            )
        except JWTError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid Supabase signature: {exc}",
            ) from exc

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
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid access token")
