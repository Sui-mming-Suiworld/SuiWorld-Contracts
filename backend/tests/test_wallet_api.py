import os
from decimal import Decimal
from typing import Any, Dict

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")
os.environ.setdefault("SECRET_KEY", "bootstrap-secret")
os.environ.setdefault("ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "15")
os.environ.setdefault("SUI_RPC_URL", "https://fullnode.devnet.sui.io:443")

from app.api.wallet import _IDEMPOTENCY_CACHE, get_wallet_service
from app.config import settings
from app.main import app
from app.services.wallet import SwapQuote, WalletServiceError


class StubWalletService:
    def __init__(self) -> None:
        self.sui_balance = 1_000_000_000  # 1 SUI in base units
        self.swt_balance = 500_000_000  # 500 SWT in base units
        self.executions = 0

    async def get_coin_balance(self, address: str, coin_type: str) -> int:  # pragma: no cover - simple stub
        return self.swt_balance if coin_type.endswith("::SWT") else self.sui_balance

    async def compute_swap_quote(
        self,
        pay_symbol: str,
        receive_symbol: str,
        pay_amount_int: int,
    ) -> SwapQuote:
        fee_amount = (pay_amount_int * 30) // 10_000
        receive_amount = pay_amount_int // 2
        return SwapQuote(
            receive_amount=receive_amount,
            fee_amount=fee_amount,
            sui_reserve=10**12,
            swt_reserve=10**12,
        )

    async def execute_swap(
        self,
        pay_symbol: str,
        receive_symbol: str,
        pay_amount_int: int,
        min_receive_amount: int,
    ) -> Dict[str, Any]:
        self.executions += 1
        if min_receive_amount > pay_amount_int:
            raise WalletServiceError("min receive too high")
        return {
            "txDigest": "mock-digest",
            "timestampMs": 1_700_000_000_000,
        }


@pytest.fixture(autouse=True)
def configure_settings():
    settings.SUIWORLD_PACKAGE_ID = "0xpackage"
    settings.SUIWORLD_SWAP_POOL_ID = "0xpool"
    settings.TREASURY_SUI_ADDRESS = "0xsuia"
    settings.TREASURY_SWT_ADDRESS = "0xswta"
    settings.TREASURY_BTC_ADDRESS = "bc1btcaddress"
    settings.TREASURY_ETH_ADDRESS = "0xethaddress"
    settings.TREASURY_BTC_BALANCE = Decimal("1.23456789")
    settings.TREASURY_ETH_BALANCE = Decimal("2.5")
    settings.SWT_PRICE_USD = Decimal("0.50")
    settings.SUI_PRICE_USD = Decimal("1.00")
    settings.BTC_PRICE_USD = Decimal("65000")
    settings.ETH_PRICE_USD = Decimal("3000")
    yield
    _IDEMPOTENCY_CACHE.clear()
    app.dependency_overrides.clear()


@pytest.fixture
def wallet_stub() -> StubWalletService:
    return StubWalletService()


@pytest.fixture
def client(wallet_stub: StubWalletService) -> TestClient:
    app.dependency_overrides[get_wallet_service] = lambda: wallet_stub
    _IDEMPOTENCY_CACHE.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    _IDEMPOTENCY_CACHE.clear()


def test_wallet_summary_returns_assets(client: TestClient):
    response = client.get("/wallet/summary")
    assert response.status_code == 200

    payload = response.json()
    assets = payload["assets"]
    assert [asset["symbol"] for asset in assets] == ["SWT", "SUI", "BTC", "ETH"]
    for asset in assets:
        assert isinstance(asset["amount"], str)
        assert isinstance(asset["usdValue"], str)
        assert isinstance(asset["priceUsd"], str)


def test_wallet_address_returns_configured_entry(client: TestClient):
    response = client.get("/wallet/address/SUI")
    assert response.status_code == 200
    assert response.json() == {
        "symbol": "SUI",
        "address": "0xsuia",
        "chain": "sui",
    }


def test_swap_quote_rejects_same_symbol(client: TestClient):
    response = client.post(
        "/wallet/swap/quote",
        json={
            "paySymbol": "SUI",
            "receiveSymbol": "SUI",
            "payAmount": "1",
        },
    )
    assert response.status_code == 400
    assert response.json()["code"] == "WALLET_SAME_SYMBOL"


def test_swap_quote_returns_expected_numbers(client: TestClient):
    response = client.post(
        "/wallet/swap/quote",
        json={
            "paySymbol": "SUI",
            "receiveSymbol": "SWT",
            "payAmount": "1",
        },
    )
    assert response.status_code == 200

    payload = response.json()
    assert payload["payAmount"] == "1.000000000"
    assert payload["receiveAmount"] == "500.000000"
    assert payload["feeAmount"] == "0.003000000"
    assert payload["feeRateBps"] == 30
    assert payload["price"] == "500.000000"


def test_swap_execute_honours_idempotency(client: TestClient, wallet_stub: StubWalletService):
    request_body = {
        "paySymbol": "SUI",
        "receiveSymbol": "SWT",
        "payAmount": "1",
        "idempotencyKey": "swap-1",
    }

    first = client.post("/wallet/swap/execute", json=request_body)
    assert first.status_code == 200
    second = client.post("/wallet/swap/execute", json=request_body)
    assert second.status_code == 200

    assert wallet_stub.executions == 1
    assert first.json()["txDigest"] == second.json()["txDigest"] == "mock-digest"

