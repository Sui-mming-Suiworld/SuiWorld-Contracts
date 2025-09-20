from __future__ import annotations

import base64
import hashlib
import logging
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

import httpx
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from ..config import Settings

logger = logging.getLogger(__name__)

SUI_COIN_TYPE = "0x2::sui::SUI"


class WalletServiceError(Exception):
    """Raised when the wallet service encounters a recoverable error."""

    def __init__(self, message: str, code: str = "WALLET_CHAIN_UNAVAILABLE") -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class SwapQuote:
    receive_amount: int
    fee_amount: int
    sui_reserve: int
    swt_reserve: int


@dataclass(frozen=True)
class CoinPlan:
    gas_coin_id: str
    source_coin_id: str
    needs_split: bool
    preselected_pay_coin_id: Optional[str] = None


class WalletService:
    """High-level helper around the Sui JSON-RPC interface."""

    JSON_RPC_VERSION = "2.0"
    REQUEST_ID = "wallet"
    FEE_BPS = 30
    BPS_SCALE = 10_000
    GAS_BUDGET_SPLIT = 2_000_000
    GAS_BUDGET_SWAP = 5_000_000
    GAS_CUSHION = 500_000

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._service_address: Optional[str] = None
        self._private_key: Optional[Ed25519PrivateKey] = None
        self._public_key_bytes: Optional[bytes] = None
        self._signature_flag: Optional[int] = None

    @property
    def _min_gas_reserve(self) -> int:
        return self.GAS_BUDGET_SPLIT + self.GAS_BUDGET_SWAP + self.GAS_CUSHION

    async def call_rpc(self, method: str, params: list[Any]) -> Dict[str, Any]:
        payload = {
            "jsonrpc": self.JSON_RPC_VERSION,
            "method": method,
            "params": params,
            "id": self.REQUEST_ID,
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(self.settings.SUI_RPC_URL, json=payload)
                response.raise_for_status()
        except httpx.HTTPError as exc:
            logger.exception("Sui RPC request failed: %s", exc)
            raise WalletServiceError("Unable to reach Sui RPC") from exc

        data = response.json()
        if "error" in data:
            error = data["error"]
            message = error.get("message", "Sui RPC responded with an error") if isinstance(error, dict) else str(error)
            logger.error("Sui RPC returned error for %s: %s", method, message)
            raise WalletServiceError(message)

        result = data.get("result")
        if result is None:
            logger.error("Sui RPC returned no result for %s", method)
            raise WalletServiceError("Sui RPC returned no result")

        return result

    async def get_coin_balance(self, address: str, coin_type: str) -> int:
        result = await self.call_rpc("suix_getBalance", [address, coin_type])
        balance_str = result.get("totalBalance") if isinstance(result, dict) else None
        try:
            return int(balance_str) if balance_str is not None else 0
        except (TypeError, ValueError) as exc:
            logger.error("Invalid balance payload for %s: %s", coin_type, result)
            raise WalletServiceError("Invalid balance payload") from exc

    async def get_swap_pool_state(self) -> Tuple[int, int]:
        options = {"showContent": True}
        result = await self.call_rpc("sui_getObject", [self.settings.SUIWORLD_SWAP_POOL_ID, options])

        data = result.get("data") if isinstance(result, dict) else None
        if not isinstance(data, dict):
            raise WalletServiceError("Swap pool state unavailable")

        content = data.get("content")
        if not isinstance(content, dict):
            raise WalletServiceError("Swap pool content missing")

        fields = content.get("fields")
        if not isinstance(fields, dict):
            raise WalletServiceError("Swap pool fields missing")

        sui_balance_obj = fields.get("sui_balance")
        swt_balance_obj = fields.get("swt_balance")

        sui_reserve = self._extract_balance_value(sui_balance_obj)
        swt_reserve = self._extract_balance_value(swt_balance_obj)

        return sui_reserve, swt_reserve

    def _extract_balance_value(self, balance_obj: Any) -> int:
        if isinstance(balance_obj, dict):
            fields = balance_obj.get("fields")
            if isinstance(fields, dict):
                if "value" in fields:
                    try:
                        return int(fields["value"])
                    except (TypeError, ValueError) as exc:
                        raise WalletServiceError("Invalid reserve value") from exc
                if "balance" in fields and isinstance(fields["balance"], dict):
                    nested = fields["balance"].get("fields")
                    if isinstance(nested, dict) and "value" in nested:
                        try:
                            return int(nested["value"])
                        except (TypeError, ValueError) as exc:
                            raise WalletServiceError("Invalid reserve value") from exc
        raise WalletServiceError("Malformed balance object")

    async def compute_swap_quote(self, pay_symbol: str, receive_symbol: str, pay_amount_int: int) -> SwapQuote:
        if pay_amount_int <= 0:
            raise WalletServiceError("Swap amount must be positive", code="WALLET_SWAP_FAILED")

        sui_reserve, swt_reserve = await self.get_swap_pool_state()

        if pay_symbol == "SUI" and receive_symbol == "SWT":
            input_reserve, output_reserve = sui_reserve, swt_reserve
        elif pay_symbol == "SWT" and receive_symbol == "SUI":
            input_reserve, output_reserve = swt_reserve, sui_reserve
        else:
            raise WalletServiceError("Unsupported swap pair", code="WALLET_SWAP_FAILED")

        if input_reserve <= 0 or output_reserve <= 0:
            raise WalletServiceError("Swap pool is empty")

        input_with_fee = pay_amount_int * (self.BPS_SCALE - self.FEE_BPS)
        numerator = output_reserve * input_with_fee
        denominator = input_reserve * self.BPS_SCALE + input_with_fee

        if denominator == 0:
            raise WalletServiceError("Invalid swap calculation")

        receive_amount = numerator // denominator
        fee_amount = (pay_amount_int * self.FEE_BPS) // self.BPS_SCALE

        return SwapQuote(
            receive_amount=receive_amount,
            fee_amount=fee_amount,
            sui_reserve=sui_reserve,
            swt_reserve=swt_reserve,
        )

    async def execute_swap(
        self,
        pay_symbol: str,
        receive_symbol: str,
        pay_amount_int: int,
        min_receive_amount: int,
    ) -> Dict[str, Any]:
        self._ensure_service_account()

        if pay_symbol == "SUI" and receive_symbol == "SWT":
            response = await self._execute_sui_to_swt(pay_amount_int, min_receive_amount)
        elif pay_symbol == "SWT" and receive_symbol == "SUI":
            response = await self._execute_swt_to_sui(pay_amount_int, min_receive_amount)
        else:
            raise WalletServiceError("Unsupported swap pair", code="WALLET_SWAP_FAILED")

        effects = response.get("effects") or {}
        status = effects.get("status", {}).get("status") if isinstance(effects, dict) else None
        if status != "success":
            error_message = effects.get("status", {}).get("error") if isinstance(effects, dict) else None
            raise WalletServiceError(error_message or "Swap execution failed", code="WALLET_SWAP_FAILED")

        return response

    def _ensure_service_account(self) -> None:
        if self._service_address is not None and self._private_key is not None:
            return

        encoded_key = (self.settings.SUIWORLD_SERVICE_KEY or "").strip()
        if not encoded_key:
            raise WalletServiceError("Service key not configured", code="WALLET_CHAIN_UNAVAILABLE")

        try:
            raw = base64.b64decode(encoded_key)
        except (ValueError, TypeError) as exc:
            logger.error("Invalid service key encoding")
            raise WalletServiceError("Service key is invalid", code="WALLET_CHAIN_UNAVAILABLE") from exc

        if len(raw) not in (33, 65):
            raise WalletServiceError("Service key length is invalid", code="WALLET_CHAIN_UNAVAILABLE")

        self._signature_flag = raw[0]
        if self._signature_flag != 0:
            raise WalletServiceError("Unsupported key scheme", code="WALLET_CHAIN_UNAVAILABLE")

        private_bytes = raw[1:33]
        try:
            self._private_key = Ed25519PrivateKey.from_private_bytes(private_bytes)
        except ValueError as exc:
            raise WalletServiceError("Unable to load service key", code="WALLET_CHAIN_UNAVAILABLE") from exc

        if len(raw) == 65:
            self._public_key_bytes = raw[33:65]
        else:
            self._public_key_bytes = self._private_key.public_key().public_bytes(
                encoding=serialization.Encoding.Raw,
                format=serialization.PublicFormat.Raw,
            )

        digest = hashlib.blake2b(self._public_key_bytes, digest_size=32).digest()
        self._service_address = "0x" + digest.hex()

    async def _execute_sui_to_swt(self, pay_amount_int: int, min_receive_amount: int) -> Dict[str, Any]:
        plan = await self._plan_sui_payment(pay_amount_int)
        pay_coin_id = plan.preselected_pay_coin_id

        if plan.needs_split:
            pay_coin_id = await self._split_coin(plan.source_coin_id, pay_amount_int, plan.gas_coin_id)

        if not pay_coin_id:
            raise WalletServiceError("Unable to determine payment coin", code="WALLET_SWAP_FAILED")

        arguments = [
            {"type": "object", "objectId": self.settings.SUIWORLD_SWAP_POOL_ID},
            {"type": "object", "objectId": pay_coin_id},
            {"type": "pure", "valueType": "u64", "value": str(min_receive_amount)},
        ]

        tx_bytes = await self._unsafe_move_call(
            module="swap",
            function="swap_sui_to_swt",
            arguments=arguments,
            gas=plan.gas_coin_id,
            gas_budget=self.GAS_BUDGET_SWAP,
        )

        tx_bytes_value = tx_bytes.get("txBytes") if isinstance(tx_bytes, dict) else None
        if not isinstance(tx_bytes_value, str):
            raise WalletServiceError("Failed to build swap transaction", code="WALLET_SWAP_FAILED")

        return await self._execute_transaction(tx_bytes_value)

    async def _execute_swt_to_sui(self, pay_amount_int: int, min_receive_amount: int) -> Dict[str, Any]:
        gas_coin_id = await self._select_gas_coin()
        plan = await self._plan_swt_payment(pay_amount_int, gas_coin_id)
        pay_coin_id = plan.preselected_pay_coin_id

        if plan.needs_split:
            pay_coin_id = await self._split_coin(plan.source_coin_id, pay_amount_int, gas_coin_id)

        if not pay_coin_id:
            raise WalletServiceError("Unable to determine payment coin", code="WALLET_SWAP_FAILED")

        arguments = [
            {"type": "object", "objectId": self.settings.SUIWORLD_SWAP_POOL_ID},
            {"type": "object", "objectId": pay_coin_id},
            {"type": "pure", "valueType": "u64", "value": str(min_receive_amount)},
        ]

        tx_bytes = await self._unsafe_move_call(
            module="swap",
            function="swap_swt_to_sui",
            arguments=arguments,
            gas=gas_coin_id,
            gas_budget=self.GAS_BUDGET_SWAP,
        )

        tx_bytes_value = tx_bytes.get("txBytes") if isinstance(tx_bytes, dict) else None
        if not isinstance(tx_bytes_value, str):
            raise WalletServiceError("Failed to build swap transaction", code="WALLET_SWAP_FAILED")

        return await self._execute_transaction(tx_bytes_value)

    async def _plan_sui_payment(self, amount: int) -> CoinPlan:
        coins = await self._list_coins(self._service_address, SUI_COIN_TYPE)
        if not coins:
            raise WalletServiceError("Service account has no SUI", code="WALLET_CHAIN_UNAVAILABLE")

        coins_sorted = sorted(coins, key=lambda item: int(item["balance"]), reverse=True)
        gas_candidate = coins_sorted[0]
        gas_balance = int(gas_candidate["balance"]) 
        gas_coin_id = gas_candidate["coinObjectId"]

        if gas_balance < self._min_gas_reserve:
            raise WalletServiceError("Insufficient SUI for gas", code="WALLET_CHAIN_UNAVAILABLE")

        if gas_balance >= amount + self._min_gas_reserve:
            return CoinPlan(gas_coin_id=gas_coin_id, source_coin_id=gas_coin_id, needs_split=True)

        for coin in coins_sorted[1:]:
            balance = int(coin["balance"])
            if balance >= amount:
                needs_split = balance != amount
                return CoinPlan(
                    gas_coin_id=gas_coin_id,
                    source_coin_id=coin["coinObjectId"],
                    needs_split=needs_split,
                    preselected_pay_coin_id=None if needs_split else coin["coinObjectId"],
                )

        raise WalletServiceError("Service account cannot fund swap", code="WALLET_CHAIN_UNAVAILABLE")

    async def _plan_swt_payment(self, amount: int, gas_coin_id: str) -> CoinPlan:
        package_id = (self.settings.SUIWORLD_PACKAGE_ID or "").strip()
        if not package_id:
            raise WalletServiceError("SUIWORLD_PACKAGE_ID not configured", code="WALLET_CHAIN_UNAVAILABLE")

        swt_type = f"{package_id}::token::SWT"
        coins = await self._list_coins(self._service_address, swt_type)
        if not coins:
            raise WalletServiceError("Service account has no SWT", code="WALLET_CHAIN_UNAVAILABLE")

        coins_sorted = sorted(coins, key=lambda item: int(item["balance"]), reverse=True)
        for coin in coins_sorted:
            balance = int(coin["balance"])
            if balance >= amount:
                needs_split = balance != amount
                return CoinPlan(
                    gas_coin_id=gas_coin_id,
                    source_coin_id=coin["coinObjectId"],
                    needs_split=needs_split,
                    preselected_pay_coin_id=None if needs_split else coin["coinObjectId"],
                )

        raise WalletServiceError("Service account cannot fund swap", code="WALLET_CHAIN_UNAVAILABLE")

    async def _select_gas_coin(self) -> str:
        coins = await self._list_coins(self._service_address, SUI_COIN_TYPE)
        if not coins:
            raise WalletServiceError("Service account has no SUI", code="WALLET_CHAIN_UNAVAILABLE")

        coins_sorted = sorted(coins, key=lambda item: int(item["balance"]), reverse=True)
        for coin in coins_sorted:
            if int(coin["balance"]) >= self._min_gas_reserve:
                return coin["coinObjectId"]

        raise WalletServiceError("Insufficient SUI for gas", code="WALLET_CHAIN_UNAVAILABLE")

    async def _list_coins(self, owner: Optional[str], coin_type: str) -> List[Dict[str, Any]]:
        if owner is None:
            raise WalletServiceError("Service address unavailable", code="WALLET_CHAIN_UNAVAILABLE")

        coins: List[Dict[str, Any]] = []
        cursor: Optional[str] = None
        while True:
            page = await self.call_rpc("suix_getCoins", [owner, coin_type, cursor, 200])
            page_data = page.get("data", []) if isinstance(page, dict) else []
            coins.extend(page_data)
            if not page.get("hasNextPage"):
                break
            cursor = page.get("nextCursor")
            if cursor is None:
                break
        return coins

    async def _split_coin(self, coin_object_id: str, amount: int, gas_coin_id: str) -> str:
        split_bytes = await self.call_rpc(
            "unsafe_splitCoin",
            [
                self._service_address,
                coin_object_id,
                [str(amount)],
                gas_coin_id,
                str(self.GAS_BUDGET_SPLIT),
            ],
        )

        tx_bytes_value = split_bytes.get("txBytes") if isinstance(split_bytes, dict) else None
        if not isinstance(tx_bytes_value, str):
            raise WalletServiceError("Failed to build split transaction", code="WALLET_SWAP_FAILED")

        response = await self._execute_transaction(tx_bytes_value)
        effects = response.get("effects", {}) if isinstance(response, dict) else {}
        created = effects.get("created") if isinstance(effects, dict) else None
        if isinstance(created, list):
            for entry in created:
                owner = entry.get("owner", {}) if isinstance(entry, dict) else {}
                if owner.get("AddressOwner") == self._service_address:
                    reference = entry.get("reference", {}) if isinstance(entry, dict) else {}
                    object_id = reference.get("objectId")
                    if object_id:
                        return object_id

        logger.error("Split coin did not yield a detectable output coin")
        raise WalletServiceError("Unable to split coin", code="WALLET_SWAP_FAILED")

    async def _unsafe_move_call(
        self,
        *,
        module: str,
        function: str,
        arguments: List[Dict[str, Any]],
        gas: Optional[str],
        gas_budget: int,
        type_arguments: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        package_id = (self.settings.SUIWORLD_PACKAGE_ID or "").strip()
        if not package_id:
            raise WalletServiceError("SUIWORLD_PACKAGE_ID not configured", code="WALLET_CHAIN_UNAVAILABLE")

        return await self.call_rpc(
            "unsafe_moveCall",
            [
                self._service_address,
                package_id,
                module,
                function,
                type_arguments or [],
                arguments,
                gas,
                str(gas_budget),
            ],
        )

    async def _execute_transaction(self, tx_bytes: str) -> Dict[str, Any]:
        signature = self._sign_transaction(tx_bytes)
        options = {
            "showEffects": True,
            "showEvents": False,
            "showObjectChanges": True,
            "showBalanceChanges": True,
        }
        return await self.call_rpc(
            "sui_executeTransactionBlock",
            [tx_bytes, [signature], options, "WaitForEffectsCert"],
        )

    def _sign_transaction(self, tx_bytes_base64: str) -> str:
        if self._private_key is None or self._public_key_bytes is None or self._signature_flag is None:
            raise WalletServiceError("Service key not initialised", code="WALLET_CHAIN_UNAVAILABLE")

        try:
            tx_bytes = base64.b64decode(tx_bytes_base64)
        except (ValueError, TypeError) as exc:
            raise WalletServiceError("Invalid transaction bytes", code="WALLET_SWAP_FAILED") from exc

        intent_message = b"\x00\x00\x00" + tx_bytes
        signature = self._private_key.sign(intent_message)
        payload = bytes([self._signature_flag]) + signature + self._public_key_bytes
        return base64.b64encode(payload).decode()

