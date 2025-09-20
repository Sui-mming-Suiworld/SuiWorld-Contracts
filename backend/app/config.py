from typing import List, Optional

from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    SUPABASE_URL: AnyHttpUrl
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    DATABASE_URL: str

    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    SUPABASE_JWT_ISSUER: Optional[AnyHttpUrl] = None
    SUPABASE_JWT_AUDIENCE: str = "authenticated"

    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000"]

    ZKLOGIN_JWT_PUBLIC_KEY: Optional[str] = None
    ZKLOGIN_JWT_AUDIENCE: Optional[str] = None
    ZKLOGIN_JWT_ISSUER: Optional[str] = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def split_origins(cls, value):  # type: ignore[override]
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    def supabase_issuer(self) -> str:
        return str(self.SUPABASE_JWT_ISSUER or f"{self.SUPABASE_URL.rstrip('/')}/auth/v1")


settings = Settings()
