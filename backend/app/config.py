from __future__ import annotations

from decimal import Decimal
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Global application settings loaded from environment variables."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    SUPABASE_URL: str = Field(default="")
    SUPABASE_ANON_KEY: str = Field(default="")
    SUPABASE_SERVICE_ROLE_KEY: str = Field(default="")
    DATABASE_URL: str = Field(default="")

    SECRET_KEY: str = Field(default="")
    ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=15)
    ALLOWED_ORIGINS: List[str] = Field(default_factory=lambda: ["http://localhost:3000"])

    SUI_RPC_URL: str = Field(default="https://fullnode.devnet.sui.io:443")
    SUIWORLD_PACKAGE_ID: str = Field(default="")
    SUIWORLD_SWAP_POOL_ID: str = Field(default="")
    SUIWORLD_SERVICE_KEY: str = Field(default="")

    TREASURY_SUI_ADDRESS: str = Field(default="")
    TREASURY_SWT_ADDRESS: str = Field(default="")
    TREASURY_BTC_ADDRESS: str = Field(default="")
    TREASURY_ETH_ADDRESS: str = Field(default="")

    TREASURY_BTC_BALANCE: Decimal = Field(default=Decimal("0"))
    TREASURY_ETH_BALANCE: Decimal = Field(default=Decimal("0"))

    SWT_PRICE_USD: Decimal = Field(default=Decimal("0"))
    SUI_PRICE_USD: Decimal = Field(default=Decimal("0"))
    BTC_PRICE_USD: Decimal = Field(default=Decimal("0"))
    ETH_PRICE_USD: Decimal = Field(default=Decimal("0"))


settings = Settings()

