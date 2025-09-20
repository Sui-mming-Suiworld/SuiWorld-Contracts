from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, status
from jose import JWTError, jwt
from pydantic import BaseModel, Field, validator

from ..config import settings


router = APIRouter()


class ZkLoginProof(BaseModel):
    proof: Dict[str, Any] = Field(..., description="zkLogin proof payload returned by the Sui SDK")
    public_inputs: Optional[List[str]] = Field(None, alias="publicInputs", description="Public inputs used to verify the proof")
    max_epoch: Optional[int] = Field(None, alias="maxEpoch", description="Upper bound epoch for which the proof is valid")
    jwt_randomness: Optional[str] = Field(None, alias="jwtRandomness", description="Randomness used when generating the JWT")

    class Config:
        allow_population_by_field_name = True

    @validator("proof")
    def validate_proof(cls, value: Dict[str, Any]) -> Dict[str, Any]:
        if not value:
            raise ValueError("proof cannot be empty")
        return value

    @validator("public_inputs")
    def validate_public_inputs(cls, value: Optional[List[str]]) -> Optional[List[str]]:
        if value is not None and not value:
            raise ValueError("publicInputs cannot be empty")
        return value

    @validator("max_epoch")
    def validate_max_epoch(cls, value: Optional[int]) -> Optional[int]:
        if value is not None and value <= 0:
            raise ValueError("maxEpoch must be a positive integer")
        return value


class ZkLoginRequest(BaseModel):
    provider: str = Field(..., description="OIDC provider used for the zkLogin flow")
    jwt: str = Field(..., description="OIDC ID token associated with the zkLogin proof")
    nonce: str = Field(..., description="Nonce supplied to the OIDC provider when generating the proof")
    address: str = Field(..., alias="suiAddress", description="Sui address derived from the zkLogin proof")
    session_key: str = Field(..., alias="sessionKey", description="Ephemeral public key bound to the session on-chain")
    signature: str = Field(..., description="Signature proving control of the derived address and session key")
    proof: ZkLoginProof

    class Config:
        allow_population_by_field_name = True

    @validator("provider", "jwt", "nonce", "session_key", "signature", pre=True)
    def validate_non_empty(cls, value: str) -> str:
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                raise ValueError("value cannot be empty")
            return stripped
        raise ValueError("value must be a string")

    @validator("address")
    def validate_address(cls, value: str) -> str:
        if not isinstance(value, str):
            raise ValueError("address must be a string")
        stripped = value.strip().lower()
        if not stripped.startswith("0x"):
            raise ValueError("address must start with 0x")
        hex_part = stripped[2:]
        if not hex_part:
            raise ValueError("address must contain hexadecimal characters after 0x")
        try:
            int(hex_part, 16)
        except ValueError as exc:
            raise ValueError("address must be a valid hexadecimal string") from exc
        return "0x" + hex_part


@router.post("/zk-login")
def zk_login(payload: ZkLoginRequest):
    try:
        claims = jwt.get_unverified_claims(payload.jwt)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid OIDC token: {exc}",
        ) from exc

    now = datetime.now(timezone.utc)

    exp_timestamp = claims.get("exp")
    if exp_timestamp is not None:
        try:
            exp_dt = datetime.fromtimestamp(exp_timestamp, tz=timezone.utc)
        except (TypeError, ValueError) as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid exp claim in OIDC token",
            ) from exc
        if exp_dt <= now:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="OIDC token has expired",
            )
    else:
        exp_dt = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    nonce_claim = claims.get("nonce")
    if nonce_claim and nonce_claim != payload.nonce:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nonce mismatch between proof and OIDC token",
        )

    session_expiration = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    session_payload = {
        "sub": claims.get("sub"),
        "provider": payload.provider,
        "sui_address": payload.address,
        "session_key": payload.session_key,
        "iat": int(now.timestamp()),
        "exp": int(session_expiration.timestamp()),
    }
    session_token = jwt.encode(
        session_payload,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

    proof_summary = {
        "maxEpoch": payload.proof.max_epoch,
        "publicInputsCount": len(payload.proof.public_inputs) if payload.proof.public_inputs else 0,
        "jwtRandomness": payload.proof.jwt_randomness,
    }

    return {
        "address": payload.address,
        "provider": payload.provider,
        "session_token": session_token,
        "session_expires_at": session_expiration.isoformat(),
        "oidc_claims": {
            "sub": claims.get("sub"),
            "email": claims.get("email"),
            "nonce": nonce_claim,
            "expires_at": exp_dt.isoformat() if exp_dt else None,
        },
        "proof": proof_summary,
    }
