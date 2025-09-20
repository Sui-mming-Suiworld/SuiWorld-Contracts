"""Wallet API endpoints for balance summaries, swap quotes, and address lookups."""
from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
from typing import Dict, List, Literal, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app import chain as chain_module
from app.security import get_current_user

router = APIRouter(prefix="/api/wallet", tags=["wallet"])

FEE_BPS = 1  # 0.01%
IDEMPOTENCY_TTL = timedelta(minutes=5)
QUOTE_TTL_SECONDS = 30
ASSET_SYMBOLS: Tuple[str, ...] = ("SWT", "SUI", "BTC", "ETH")
SWAPPABLE_SYMBOLS: Tuple[str, ...] = ("SWT", "SUI")
_OPTIONAL_CHAIN_SYMBOLS = {"BTC", "ETH"}


def _decimal_encoder(value: Decimal) -> str:
    """Serialize Decimal as string to keep precision for the frontend."""
    return format(value, "f")


class WalletBaseModel(BaseModel):
    class Config:
        json_encoders = {Decimal: _decimal_encoder}


class AssetBalance(WalletBaseModel):
    symbol: Literal["SWT", "SUI", "BTC", "ETH"]
    logo_url: Optional[str] = None
    amount: Decimal
    usd_value: Decimal
    price_usd: Decimal


class WalletSummaryResp(WalletBaseModel):
    assets: List[AssetBalance]
    updated_at: datetime


class SwapQuoteReq(WalletBaseModel):
    pay_symbol: Literal["SWT", "SUI"]
    receive_symbol: Literal["SWT", "SUI"]
    pay_amount: Decimal = Field(..., gt=Decimal("0"))
    slippage_bps: Optional[int] = Field(default=30, ge=0)


class SwapQuoteResp(WalletBaseModel):
    pay_symbol: str
    receive_symbol: str
    pay_amount: Decimal
    receive_amount: Decimal
    fee_rate_bps: int
    fee_amount: Decimal
    price: Decimal
    expires_at: datetime


class SwapExecReq(SwapQuoteReq):
    idempotency_key: Optional[str] = None


class SwapExecResp(WalletBaseModel):
    tx_digest: str
    chain: Literal["sui"]
    executed_at: datetime
    pay_symbol: str
    receive_symbol: str
    pay_amount: Decimal
    receive_amount: Decimal


class AddressResp(WalletBaseModel):
    symbol: Literal["SWT", "SUI", "BTC", "ETH"]
    address: str
    chain: str


_PRICE_CACHE: Optional[Tuple[datetime, Dict[str, Decimal]]] = None
_PRICE_CACHE_TTL = timedelta(minutes=5)
_IDEMPOTENCY_CACHE: Dict[str, Tuple[datetime, SwapExecResp]] = {}


def _wallet_error(status_code: int, code: str, detail: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail={"detail": detail, "code": code})


def _get_user_identifier(user: object) -> str:
    if isinstance(user, dict):
        for key in ("id", "user_id", "username", "email"):
            value = user.get(key)
            if value:
                return str(value)
        return "unknown"
    for attr in ("id", "user_id", "username", "email"):
        value = getattr(user, attr, None)
        if value:
            return str(value)
    return str(user)


def _get_prices_usd() -> Dict[str, Decimal]:
    # TODO(pricing): Replace with external oracle integration.
    global _PRICE_CACHE
    now = datetime.utcnow()
    if _PRICE_CACHE and (now - _PRICE_CACHE[0]) < _PRICE_CACHE_TTL:
        return _PRICE_CACHE[1]

    prices = {
        "SWT": Decimal("0.001"),
        "SUI": Decimal("3.66"),
        "BTC": Decimal("155500"),
        "ETH": Decimal("4500"),
    }
    _PRICE_CACHE = (now, prices)
    return prices


def _get_chain_callable(name: str):
    func = getattr(chain_module, name, None)
    if not callable(func):
        raise _wallet_error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "WALLET_CHAIN_UNAVAILABLE",
            f"Chain adapter '{name}' not available.",
        )
    return func


def _get_user_address(user_identifier: str, symbol: str, *, optional: bool = False) -> Optional[str]:
    try:
        func = _get_chain_callable("get_user_address")
    except HTTPException:
        if optional:
            return None
        raise
    try:
        address = func(user_identifier, symbol)
    except Exception as exc:  # noqa: BLE001 - bubble up as wallet error
        if optional:
            return None
        raise _wallet_error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "WALLET_CHAIN_UNAVAILABLE",
            f"Unable to fetch {symbol} address: {exc}",
        ) from exc
    return address


def _to_decimal(value: object) -> Decimal:
    if isinstance(value, Decimal):
        return value
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError) as exc:
        raise _wallet_error(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "WALLET_DECIMAL_PARSE_ERROR",
            "Unable to parse numeric response from chain adapter.",
        ) from exc


def _get_asset_balance(
    current_user: object,
    user_identifier: str,
    symbol: str,
    *,
    optional: bool = False,
) -> Decimal:
    address = _get_user_address(user_identifier, symbol, optional=optional)
    if not address:
        if optional:
            return Decimal("0")
        raise _wallet_error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "WALLET_CHAIN_UNAVAILABLE",
            f"Address for {symbol} unavailable.",
        )

    try:
        if symbol == "SUI":
            func = _get_chain_callable("get_sui_balance")
            raw_balance = func(address)
        else:
            func = _get_chain_callable("get_token_balance")
            raw_balance = func(address, symbol)
    except HTTPException:
        if optional:
            return Decimal("0")
        raise
    except Exception as exc:  # noqa: BLE001 - rewrap
        if optional:
            return Decimal("0")
        raise _wallet_error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "WALLET_CHAIN_UNAVAILABLE",
            f"Unable to fetch {symbol} balance: {exc}",
        ) from exc

    return _to_decimal(raw_balance)


def _compute_quote(pay_symbol: str, receive_symbol: str, pay_amount: Decimal) -> Tuple[Decimal, Decimal, Decimal]:
    if pay_symbol == receive_symbol:
        raise _wallet_error(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_SAME_SYMBOL",
            "Cannot swap the same asset.",
        )

    prices = _get_prices_usd()
    try:
        price_pay = prices[pay_symbol]
        price_receive = prices[receive_symbol]
    except KeyError as exc:
        raise _wallet_error(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_ASSET_UNSUPPORTED",
            f"Unsupported asset: {exc.args[0]}",
        ) from exc

    # Gross output before fee.
    gross_receive = (pay_amount * price_pay) / price_receive
    fee_amount = (gross_receive * Decimal(FEE_BPS) / Decimal("10000"))
    receive_amount = gross_receive - fee_amount
    price = price_pay / price_receive
    return receive_amount, fee_amount, price


def _ensure_balance_available(
    current_user: object,
    user_identifier: str,
    symbol: str,
    required_amount: Decimal,
) -> None:
    optional = symbol in _OPTIONAL_CHAIN_SYMBOLS
    balance = _get_asset_balance(current_user, user_identifier, symbol, optional=optional)
    if balance is None:
        raise _wallet_error(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_BALANCE_UNKNOWN",
            "Unable to determine asset balance.",
        )
    if balance < required_amount:
        raise _wallet_error(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_INSUFFICIENT_FUNDS",
            f"Insufficient {symbol} balance.",
        )


def _clean_idempotency_cache() -> None:
    now = datetime.utcnow()
    expired_keys = [key for key, (ts, _) in _IDEMPOTENCY_CACHE.items() if now - ts > IDEMPOTENCY_TTL]
    for key in expired_keys:
        _IDEMPOTENCY_CACHE.pop(key, None)


@router.get("/summary", response_model=WalletSummaryResp)
def get_wallet_summary(current_user: object = Depends(get_current_user)) -> WalletSummaryResp:
    user_identifier = _get_user_identifier(current_user)
    prices = _get_prices_usd()
    updated_at = datetime.utcnow()

    assets: List[AssetBalance] = []
    for symbol in ASSET_SYMBOLS:
        optional = symbol in _OPTIONAL_CHAIN_SYMBOLS
        balance = _get_asset_balance(current_user, user_identifier, symbol, optional=optional)
        usd_value = balance * prices[symbol]
        assets.append(
            AssetBalance(
                symbol=symbol, amount=balance, price_usd=prices[symbol], usd_value=usd_value
            )
        )

    return WalletSummaryResp(assets=assets, updated_at=updated_at)


@router.post("/swap/quote", response_model=SwapQuoteResp)
def get_swap_quote(
    quote_req: SwapQuoteReq, current_user: object = Depends(get_current_user)
) -> SwapQuoteResp:  # noqa: ARG001 - current_user reserved for auth checks
    receive_amount, fee_amount, price = _compute_quote(
        quote_req.pay_symbol, quote_req.receive_symbol, quote_req.pay_amount
    )
    expires_at = datetime.utcnow() + timedelta(seconds=QUOTE_TTL_SECONDS)
    return SwapQuoteResp(
        pay_symbol=quote_req.pay_symbol,
        receive_symbol=quote_req.receive_symbol,
        pay_amount=quote_req.pay_amount,
        receive_amount=receive_amount,
        fee_rate_bps=FEE_BPS,
        fee_amount=fee_amount,
        price=price,
        expires_at=expires_at,
    )


@router.post("/swap/execute", response_model=SwapExecResp)
def execute_swap(
    exec_req: SwapExecReq,
    current_user: object = Depends(get_current_user),
) -> SwapExecResp:
    user_identifier = _get_user_identifier(current_user)
    pay_symbol = exec_req.pay_symbol
    receive_symbol = exec_req.receive_symbol
    pay_amount = exec_req.pay_amount

    if pay_symbol == receive_symbol:
        raise _wallet_error(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_SAME_SYMBOL",
            "Cannot swap the same asset.",
        )

    if pay_symbol not in SWAPPABLE_SYMBOLS or receive_symbol not in SWAPPABLE_SYMBOLS:
        raise _wallet_error(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_ASSET_UNSUPPORTED",
            "Only SUI and SWT swaps are supported.",
        )

    _ensure_balance_available(current_user, user_identifier, pay_symbol, pay_amount)

    idempotency_key = exec_req.idempotency_key
    if idempotency_key:
        _clean_idempotency_cache()
        cached = _IDEMPOTENCY_CACHE.get(idempotency_key)
        if cached:
            _, cached_resp = cached
            return cached_resp

    try:
        expected_receive_amount, _, _ = _compute_quote(pay_symbol, receive_symbol, pay_amount)
    except HTTPException:
        raise
    if expected_receive_amount <= Decimal("0"):
        raise _wallet_error(
            status.HTTP_400_BAD_REQUEST,
            "WALLET_INVALID_QUOTE",
            "Calculated quote output is non-positive.",
        )

    try:
        if pay_symbol == "SUI" and receive_symbol == "SWT":
            func = _get_chain_callable("swap_sui_to_swt")
            tx_digest, receive_amount_actual = func(current_user, pay_amount, exec_req.slippage_bps or 0)
        elif pay_symbol == "SWT" and receive_symbol == "SUI":
            func = _get_chain_callable("swap_swt_to_sui")
            tx_digest, receive_amount_actual = func(current_user, pay_amount, exec_req.slippage_bps or 0)
        else:
            raise _wallet_error(
                status.HTTP_400_BAD_REQUEST,
                "WALLET_ASSET_UNSUPPORTED",
                "Unsupported swap direction.",
            )
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        raise _wallet_error(
            status.HTTP_502_BAD_GATEWAY,
            "WALLET_SWAP_FAILED",
            f"Swap execution failed: {exc}",
        ) from exc

    receive_amount_actual = _to_decimal(receive_amount_actual)
    if receive_amount_actual <= Decimal("0"):
        raise _wallet_error(
            status.HTTP_502_BAD_GATEWAY,
            "WALLET_SWAP_FAILED",
            "Swap execution returned zero output.",
        )

    # TODO(chain): Validate slippage when chain helpers expose minimum output controls.
    executed_at = datetime.utcnow()
    response = SwapExecResp(
        tx_digest=str(tx_digest),
        chain="sui",
        executed_at=executed_at,
        pay_symbol=pay_symbol,
        receive_symbol=receive_symbol,
        pay_amount=pay_amount,
        receive_amount=receive_amount_actual,
    )

    if idempotency_key:
        _IDEMPOTENCY_CACHE[idempotency_key] = (executed_at, response)

    return response


@router.get("/address/{symbol}", response_model=AddressResp)
def get_address(symbol: str, current_user: object = Depends(get_current_user)) -> AddressResp:
    symbol = symbol.upper()
    if symbol not in ASSET_SYMBOLS:
        raise _wallet_error(
            status.HTTP_404_NOT_FOUND,
            "WALLET_ASSET_UNSUPPORTED",
            f"Unsupported asset: {symbol}",
        )

    user_identifier = _get_user_identifier(current_user)
    optional = symbol in _OPTIONAL_CHAIN_SYMBOLS
    address = _get_user_address(user_identifier, symbol, optional=optional)
    if not address:
        raise _wallet_error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "WALLET_CHAIN_UNAVAILABLE",
            f"Address for {symbol} unavailable.",
        )

    chain_name = "sui"
    if symbol == "BTC":
        chain_name = "bitcoin"
    elif symbol == "ETH":
        chain_name = "ethereum"

    return AddressResp(symbol=symbol, address=address, chain=chain_name)
