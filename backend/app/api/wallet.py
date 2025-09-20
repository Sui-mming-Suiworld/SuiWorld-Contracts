from __future__ import annotations

import asyncio
import functools
import logging
from collections import OrderedDict
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_DOWN
from typing import Any, Dict, Literal, Optional

from fastapi import APIRouter, Depends, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from ..config import settings
from ..services.wallet import WalletService, WalletServiceError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/wallet")

AssetSymbol = Literal["SWT", "SUI", "BTC", "ETH"]
SwapSymbol = Literal["SWT", "SUI"]
SUI_DECIMALS = 9
SWT_DECIMALS = 6
BTC_DECIMALS = 8
ETH_DECIMALS = 18
FEE_BPS = 30
BPS_SCALE = 10_000
PRICE_DECIMALS = 6
USD_DECIMALS = 2
SUI_COIN_TYPE = "0x2::sui::SUI"

_IDEMPOTENCY_CACHE: "OrderedDict[str, SwapExecuteResponse]" = OrderedDict()
_IDEMPOTENCY_LOCK = asyncio.Lock()
_IDEMPOTENCY_LIMIT = 128


def to_camel(string: str) -> str:
    head, *tail = string.split("_")
    return head + "".join(part.capitalize() for part in tail)


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class AssetBalance(CamelModel):
    symbol: AssetSymbol
    logo_url: Optional[str] = Field(default=None, alias="logoUrl")
    amount: str
    usd_value: str = Field(alias="usdValue")
    price_usd: str = Field(alias="priceUsd")


class WalletSummary(CamelModel):
    assets: list[AssetBalance]
    updated_at: datetime = Field(alias="updatedAt")


class SwapQuoteRequest(CamelModel):
    pay_symbol: SwapSymbol = Field(alias="paySymbol")
    receive_symbol: SwapSymbol = Field(alias="receiveSymbol")
    pay_amount: str = Field(alias="payAmount")
    slippage_bps: Optional[int] = Field(default=None, alias="slippageBps")


class SwapQuoteResponse(CamelModel):
    pay_symbol: SwapSymbol = Field(alias="paySymbol")
    receive_symbol: SwapSymbol = Field(alias="receiveSymbol")
    pay_amount: str = Field(alias="payAmount")
    receive_amount: str = Field(alias="receiveAmount")
    fee_rate_bps: int = Field(alias="feeRateBps")
    fee_amount: str = Field(alias="feeAmount")
    price: str
    expires_at: datetime = Field(alias="expiresAt")


class SwapExecuteRequest(SwapQuoteRequest):
    idempotency_key: Optional[str] = Field(default=None, alias="idempotencyKey")


class SwapExecuteResponse(CamelModel):
    tx_digest: str = Field(alias="txDigest")
    chain: str
    executed_at: datetime = Field(alias="executedAt")
    pay_symbol: SwapSymbol = Field(alias="paySymbol")
    receive_symbol: SwapSymbol = Field(alias="receiveSymbol")
    pay_amount: str = Field(alias="payAmount")
    receive_amount: str = Field(alias="receiveAmount")


class AddressResponse(CamelModel):
    symbol: AssetSymbol
    address: str
    chain: str


class WalletAPIError(Exception):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


async def wallet_exception_handler(request: Request, exc: WalletAPIError):
    headers = {"X-Error-Code": exc.code}
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.message, "code": exc.code},
        headers=headers,
    )


@functools.lru_cache(maxsize=1)
def _service_factory() -> WalletService:
    return WalletService(settings)


async def get_wallet_service() -> WalletService:
    return _service_factory()


def format_amount(value_int: int, decimals: int) -> str:
    quantizer = Decimal(1).scaleb(-decimals) if decimals > 0 else Decimal(1)
    value = Decimal(value_int).scaleb(-decimals)
    return str(value.quantize(quantizer, rounding=ROUND_DOWN))


def parse_amount(amount_str: str, decimals: int) -> int:
    try:
        value = Decimal(amount_str)
    except (InvalidOperation, ValueError) as exc:
        raise WalletAPIError(status.HTTP_422_UNPROCESSABLE_ENTITY, "WALLET_UNKNOWN", "Invalid amount format") from exc

    if value <= 0:
        raise WalletAPIError(status.HTTP_422_UNPROCESSABLE_ENTITY, "WALLET_UNKNOWN", "Amount must be positive")

    fraction_digits = -value.as_tuple().exponent if value.as_tuple().exponent < 0 else 0
    if fraction_digits > 18:
        raise WalletAPIError(status.HTTP_422_UNPROCESSABLE_ENTITY, "WALLET_UNKNOWN", "Too many decimal places")
    if fraction_digits > decimals:
        raise WalletAPIError(status.HTTP_422_UNPROCESSABLE_ENTITY, "WALLET_UNKNOWN", "Amount exceeds token precision")

    scaled = (value * (Decimal(10) ** decimals)).quantize(Decimal("1"), rounding=ROUND_DOWN)
    return int(scaled)


def format_decimal(value: Decimal, decimals: int) -> str:
    quantizer = Decimal(1).scaleb(-decimals) if decimals > 0 else Decimal(1)
    return str(value.quantize(quantizer, rounding=ROUND_DOWN))


def compute_usd_value(amount_int: int, decimals: int, price: Decimal) -> str:
    token_amount = Decimal(amount_int).scaleb(-decimals)
    usd_value = token_amount * price
    return format_decimal(usd_value, USD_DECIMALS)


def compute_price(
    pay_amount_int: int,
    pay_decimals: int,
    receive_amount_int: int,
    receive_decimals: int,
) -> str:
    pay_amount = Decimal(pay_amount_int).scaleb(-pay_decimals)
    receive_amount = Decimal(receive_amount_int).scaleb(-receive_decimals)
    if pay_amount <= 0:
        return "0"
    price = receive_amount / pay_amount
    return format_decimal(price, PRICE_DECIMALS)


def get_swt_coin_type() -> str:
    package_id = settings.SUIWORLD_PACKAGE_ID.strip()
    if not package_id:
        raise WalletAPIError(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "WALLET_UNKNOWN",
            "SUIWORLD_PACKAGE_ID is not configured",
        )
    return f"{package_id}::token::SWT"


def get_swt_address() -> str:
    address = settings.TREASURY_SWT_ADDRESS.strip() or settings.TREASURY_SUI_ADDRESS.strip()
    if not address:
        raise WalletAPIError(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "WALLET_UNKNOWN",
            "Treasury address is not configured",
        )
    return address


def require_address(value: str, name: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise WalletAPIError(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "WALLET_UNKNOWN",
            f"{name} is not configured",
        )
    return stripped


async def _get_cached_execution(key: str) -> Optional[SwapExecuteResponse]:
    async with _IDEMPOTENCY_LOCK:
        cached = _IDEMPOTENCY_CACHE.get(key)
        if cached is not None:
            _IDEMPOTENCY_CACHE.move_to_end(key)
        return cached


async def _store_cached_execution(key: str, response: SwapExecuteResponse) -> None:
    async with _IDEMPOTENCY_LOCK:
        _IDEMPOTENCY_CACHE[key] = response
        _IDEMPOTENCY_CACHE.move_to_end(key)
        while len(_IDEMPOTENCY_CACHE) > _IDEMPOTENCY_LIMIT:
            _IDEMPOTENCY_CACHE.popitem(last=False)


async def build_wallet_summary(service: WalletService) -> WalletSummary:
    treasury_sui_address = require_address(settings.TREASURY_SUI_ADDRESS, "TREASURY_SUI_ADDRESS")
    swt_coin_type = get_swt_coin_type()

    sui_task = asyncio.create_task(service.get_coin_balance(treasury_sui_address, SUI_COIN_TYPE))
    swt_task = asyncio.create_task(service.get_coin_balance(treasury_sui_address, swt_coin_type))

    try:
        sui_balance_int, swt_balance_int = await asyncio.gather(sui_task, swt_task)
    except WalletServiceError:
        raise
    except Exception as exc:
        logger.exception("Unexpected error while fetching on-chain balances")
        raise WalletServiceError("Failed to fetch on-chain balances") from exc

    btc_balance = settings.TREASURY_BTC_BALANCE
    eth_balance = settings.TREASURY_ETH_BALANCE
    if btc_balance < 0 or eth_balance < 0:
        raise WalletAPIError(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "WALLET_UNKNOWN",
            "Config balances cannot be negative",
        )

    btc_balance_int = int((btc_balance * (Decimal(10) ** BTC_DECIMALS)).quantize(Decimal("1"), rounding=ROUND_DOWN))
    eth_balance_int = int((eth_balance * (Decimal(10) ** ETH_DECIMALS)).quantize(Decimal("1"), rounding=ROUND_DOWN))

    assets = [
        AssetBalance(
            symbol="SWT",
            amount=format_amount(swt_balance_int, SWT_DECIMALS),
            usd_value=compute_usd_value(swt_balance_int, SWT_DECIMALS, settings.SWT_PRICE_USD),
            price_usd=format_decimal(settings.SWT_PRICE_USD, USD_DECIMALS),
        ),
        AssetBalance(
            symbol="SUI",
            amount=format_amount(sui_balance_int, SUI_DECIMALS),
            usd_value=compute_usd_value(sui_balance_int, SUI_DECIMALS, settings.SUI_PRICE_USD),
            price_usd=format_decimal(settings.SUI_PRICE_USD, USD_DECIMALS),
        ),
        AssetBalance(
            symbol="BTC",
            amount=format_amount(btc_balance_int, BTC_DECIMALS),
            usd_value=compute_usd_value(btc_balance_int, BTC_DECIMALS, settings.BTC_PRICE_USD),
            price_usd=format_decimal(settings.BTC_PRICE_USD, USD_DECIMALS),
        ),
        AssetBalance(
            symbol="ETH",
            amount=format_amount(eth_balance_int, ETH_DECIMALS),
            usd_value=compute_usd_value(eth_balance_int, ETH_DECIMALS, settings.ETH_PRICE_USD),
            price_usd=format_decimal(settings.ETH_PRICE_USD, USD_DECIMALS),
        ),
    ]

    return WalletSummary(assets=assets, updated_at=datetime.now(timezone.utc))


@router.get("/summary", response_model=WalletSummary)
async def get_wallet_summary(service: WalletService = Depends(get_wallet_service)) -> WalletSummary:
    try:
        return await build_wallet_summary(service)
    except WalletServiceError as exc:
        logger.error("Wallet summary failed: %s", exc)
        raise WalletAPIError(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            exc.code,
            "Unable to reach Sui network",
        ) from exc
    except WalletAPIError:
        raise
    except Exception as exc:
        logger.exception("Unexpected error while building wallet summary")
        raise WalletAPIError(
            status.HTTP_502_BAD_GATEWAY,
            "WALLET_UNKNOWN",
            "Failed to build wallet summary",
        ) from exc


@router.get("/address/{symbol}", response_model=AddressResponse)
async def get_wallet_address(symbol: AssetSymbol) -> AddressResponse:
    if symbol == "SWT":
        address = get_swt_address()
        chain = "sui"
    elif symbol == "SUI":
        address = require_address(settings.TREASURY_SUI_ADDRESS, "TREASURY_SUI_ADDRESS")
        chain = "sui"
    elif symbol == "BTC":
        address = require_address(settings.TREASURY_BTC_ADDRESS, "TREASURY_BTC_ADDRESS")
        chain = "bitcoin"
    else:
        address = require_address(settings.TREASURY_ETH_ADDRESS, "TREASURY_ETH_ADDRESS")
        chain = "ethereum"

    return AddressResponse(symbol=symbol, address=address, chain=chain)


def validate_swap_symbols(pay_symbol: SwapSymbol, receive_symbol: SwapSymbol) -> None:
    if pay_symbol == receive_symbol:
        raise WalletAPIError(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_SAME_SYMBOL",
            "Pay and receive symbols must differ",
        )


def get_decimals_for_symbol(symbol: SwapSymbol) -> int:
    return SWT_DECIMALS if symbol == "SWT" else SUI_DECIMALS


@router.post("/swap/quote", response_model=SwapQuoteResponse)
async def create_swap_quote(
    payload: SwapQuoteRequest,
    service: WalletService = Depends(get_wallet_service),
) -> SwapQuoteResponse:
    validate_swap_symbols(payload.pay_symbol, payload.receive_symbol)

    pay_decimals = get_decimals_for_symbol(payload.pay_symbol)
    receive_decimals = get_decimals_for_symbol(payload.receive_symbol)

    pay_amount_int = parse_amount(payload.pay_amount, pay_decimals)

    try:
        quote = await service.compute_swap_quote(
            payload.pay_symbol,
            payload.receive_symbol,
            pay_amount_int,
        )
    except WalletServiceError as exc:
        raise WalletAPIError(status.HTTP_503_SERVICE_UNAVAILABLE, exc.code, str(exc)) from exc

    receive_amount_str = format_amount(quote.receive_amount, receive_decimals)
    fee_amount_str = format_amount(quote.fee_amount, pay_decimals)
    price_str = compute_price(pay_amount_int, pay_decimals, quote.receive_amount, receive_decimals)

    return SwapQuoteResponse(
        pay_symbol=payload.pay_symbol,
        receive_symbol=payload.receive_symbol,
        pay_amount=format_amount(pay_amount_int, pay_decimals),
        receive_amount=receive_amount_str,
        fee_rate_bps=FEE_BPS,
        fee_amount=fee_amount_str,
        price=price_str,
        expires_at=datetime.now(timezone.utc) + timedelta(seconds=30),
    )


def apply_slippage(receive_amount_int: int, slippage_bps: Optional[int]) -> int:
    slippage = slippage_bps or 0
    if slippage < 0 or slippage >= BPS_SCALE:
        raise WalletAPIError(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "WALLET_UNKNOWN",
            "Invalid slippage tolerance",
        )
    if slippage == 0:
        return receive_amount_int
    reduction = (receive_amount_int * slippage) // BPS_SCALE
    return max(receive_amount_int - reduction, 0)


def derive_execution_timestamp(execution: Dict[str, Any]) -> datetime:
    timestamp_ms = execution.get("timestampMs")
    if timestamp_ms is None:
        timestamp_ms = execution.get("timestamp")
    if isinstance(timestamp_ms, (int, float)):
        try:
            return datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc)
        except (OverflowError, OSError):
            pass
    return datetime.now(timezone.utc)


def extract_tx_digest(execution: Dict[str, Any]) -> str:
    digest = execution.get("txDigest") or execution.get("digest")
    if not isinstance(digest, str) or not digest:
        raise WalletAPIError(
            status.HTTP_502_BAD_GATEWAY,
            "WALLET_SWAP_FAILED",
            "Swap execution did not return a transaction digest",
        )
    return digest


@router.post("/swap/execute", response_model=SwapExecuteResponse)
async def execute_swap(
    payload: SwapExecuteRequest,
    service: WalletService = Depends(get_wallet_service),
) -> SwapExecuteResponse:
    validate_swap_symbols(payload.pay_symbol, payload.receive_symbol)

    pay_decimals = get_decimals_for_symbol(payload.pay_symbol)
    receive_decimals = get_decimals_for_symbol(payload.receive_symbol)
    pay_amount_int = parse_amount(payload.pay_amount, pay_decimals)

    if payload.idempotency_key:
        cached = await _get_cached_execution(payload.idempotency_key)
        if cached:
            return cached

    try:
        quote = await service.compute_swap_quote(
            payload.pay_symbol,
            payload.receive_symbol,
            pay_amount_int,
        )
    except WalletServiceError as exc:
        raise WalletAPIError(status.HTTP_503_SERVICE_UNAVAILABLE, exc.code, str(exc)) from exc

    min_receive = apply_slippage(quote.receive_amount, payload.slippage_bps)

    try:
        execution = await service.execute_swap(
            payload.pay_symbol,
            payload.receive_symbol,
            pay_amount_int,
            min_receive,
        )
    except WalletServiceError as exc:
        raise WalletAPIError(status.HTTP_502_BAD_GATEWAY, exc.code, str(exc)) from exc
    except WalletAPIError:
        raise
    except Exception as exc:
        logger.exception("Unexpected error during swap execution")
        raise WalletAPIError(
            status.HTTP_502_BAD_GATEWAY,
            "WALLET_SWAP_FAILED",
            "Swap execution failed",
        ) from exc

    tx_digest = extract_tx_digest(execution)
    executed_at = derive_execution_timestamp(execution)

    response = SwapExecuteResponse(
        tx_digest=tx_digest,
        chain="sui",
        executed_at=executed_at,
        pay_symbol=payload.pay_symbol,
        receive_symbol=payload.receive_symbol,
        pay_amount=format_amount(pay_amount_int, pay_decimals),
        receive_amount=format_amount(quote.receive_amount, receive_decimals),
    )

    if payload.idempotency_key:
        await _store_cached_execution(payload.idempotency_key, response)

    return response


