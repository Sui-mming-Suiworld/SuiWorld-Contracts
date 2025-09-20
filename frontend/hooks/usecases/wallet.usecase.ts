import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { fetcher } from "../../lib/fetcher";

export type AssetSymbol = "SWT" | "SUI" | "BTC" | "ETH";

export interface AssetBalance {
  symbol: AssetSymbol;
  logoUrl?: string;
  amount: string;
  usdValue: string;
  priceUsd: string;
}

export interface WalletSummary {
  assets: AssetBalance[];
  updatedAt: string;
}

export interface SwapQuoteReq {
  paySymbol: Extract<AssetSymbol, "SWT" | "SUI">;
  receiveSymbol: Extract<AssetSymbol, "SWT" | "SUI">;
  payAmount: string;
  slippageBps?: number;
}

export interface SwapQuoteResp {
  paySymbol: string;
  receiveSymbol: string;
  payAmount: string;
  receiveAmount: string;
  feeRateBps: number;
  feeAmount: string;
  price: string;
  expiresAt: string;
}

export interface SwapExecReq extends SwapQuoteReq {
  idempotencyKey?: string;
}

export interface SwapExecResp {
  txDigest: string;
  chain: "sui";
  executedAt: string;
  paySymbol: string;
  receiveSymbol: string;
  payAmount: string;
  receiveAmount: string;
}

export interface AddressResp {
  symbol: AssetSymbol;
  address: string;
  chain: string;
}

export class WalletApiError extends Error {
  code: string;
  status?: number;

  constructor(message: string, code: string, status?: number) {
    super(message);
    this.name = "WalletApiError";
    this.code = code;
    this.status = status;
  }

  get userMessage(): string {
    return WALLET_ERROR_MESSAGES[this.code] ?? this.message;
  }
}

const WALLET_ERROR_MESSAGES: Record<string, string> = {
  WALLET_SAME_SYMBOL: "같은 자산끼리는 스왑할 수 없어요.",
  WALLET_CHAIN_UNAVAILABLE: "현재 체인 조회가 불가합니다. 잠시 후 다시 시도해 주세요.",
};

const WALLET_API_BASE = "/api/wallet";
const DEFAULT_ERROR_MESSAGE = "요청 처리 중 문제가 발생했어요.";

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function maybeRandomId(): string | undefined {
  const globalCrypto =
    typeof globalThis !== "undefined"
      ? (globalThis as typeof globalThis & { crypto?: Crypto }).crypto
      : undefined;
  if (globalCrypto && "randomUUID" in globalCrypto && typeof globalCrypto.randomUUID === "function") {
    return globalCrypto.randomUUID();
  }
  return undefined;
}

async function walletRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const url = `${WALLET_API_BASE}${path}`;
  const body = init?.body;
  const isJsonBody = body !== undefined && typeof body !== "string";
  const requestInit: RequestInit = {
    credentials: init?.credentials ?? "include",
    ...init,
    headers: {
      Accept: "application/json",
      ...init?.headers,
      ...(isJsonBody ? { "Content-Type": "application/json" } : {}),
    },
    body: isJsonBody ? JSON.stringify(body) : body,
  };

  try {
    return await fetcher(url, requestInit);
  } catch (rawError) {
    let status = 0;
    let responseBody: unknown;

    try {
      const replayResponse = await fetch(url, requestInit);
      status = replayResponse.status;
      const text = await replayResponse.text();
      if (text) {
        try {
          responseBody = JSON.parse(text);
        } catch {
          responseBody = text;
        }
      }
    } catch (secondaryError) {
      if (secondaryError instanceof Error) {
        throw new WalletApiError(secondaryError.message, "WALLET_UNKNOWN");
      }
      throw new WalletApiError(DEFAULT_ERROR_MESSAGE, "WALLET_UNKNOWN");
    }

    const detail =
      isPlainObject(responseBody) && typeof responseBody.detail === "string"
        ? (responseBody.detail as string)
        : rawError instanceof Error
        ? rawError.message
        : DEFAULT_ERROR_MESSAGE;
    const code =
      isPlainObject(responseBody) && typeof responseBody.code === "string"
        ? (responseBody.code as string)
        : "WALLET_UNKNOWN";

    throw new WalletApiError(detail, code, status);
  }
}

function sortAssets(assets: AssetBalance[]): AssetBalance[] {
  const order: AssetSymbol[] = ["SWT", "SUI", "BTC", "ETH"];
  return [...assets].sort((a, b) => order.indexOf(a.symbol) - order.indexOf(b.symbol));
}

export async function fetchWalletSummary(): Promise<WalletSummary> {
  const summary = await walletRequest<WalletSummary>("/summary");
  return {
    ...summary,
    assets: sortAssets(summary.assets),
  };
}

export async function getSwapQuote(req: SwapQuoteReq): Promise<SwapQuoteResp> {
  return walletRequest<SwapQuoteResp>("/swap/quote", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(req),
  });
}

export async function executeSwap(req: SwapExecReq): Promise<SwapExecResp> {
  const payload: SwapExecReq = {
    ...req,
    idempotencyKey: req.idempotencyKey ?? maybeRandomId(),
  };

  return walletRequest<SwapExecResp>("/swap/execute", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

export async function getAddress(symbol: AssetSymbol): Promise<AddressResp> {
  return walletRequest<AddressResp>(`/address/${symbol}`);
}

export interface WalletSummaryState {
  summary: WalletSummary | null;
  loading: boolean;
  error: WalletApiError | null;
  refetch: () => Promise<void>;
}

export function useWalletSummary(pollMs = 30000): WalletSummaryState {
  const [summary, setSummary] = useState<WalletSummary | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<WalletApiError | null>(null);
  const pollId = useRef<ReturnType<typeof setInterval> | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchWalletSummary();
      setSummary(data);
    } catch (err) {
      setError(
        err instanceof WalletApiError
          ? err
          : new WalletApiError(DEFAULT_ERROR_MESSAGE, "WALLET_UNKNOWN")
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
    return () => {
      if (pollId.current) {
        clearInterval(pollId.current);
        pollId.current = null;
      }
    };
  }, [load]);

  useEffect(() => {
    if (pollMs <= 0) {
      if (pollId.current) {
        clearInterval(pollId.current);
        pollId.current = null;
      }
      return;
    }

    pollId.current = setInterval(() => {
      void load();
    }, pollMs);

    return () => {
      if (pollId.current) {
        clearInterval(pollId.current);
        pollId.current = null;
      }
    };
  }, [load, pollMs]);

  return {
    summary,
    loading,
    error,
    refetch: load,
  };
}

export interface UseSwapState {
  paySymbol: AssetSymbol;
  receiveSymbol: AssetSymbol;
  payAmount: string;
  quote: SwapQuoteResp | null;
  loadingQuote: boolean;
  executing: boolean;
  error: WalletApiError | null;
  userMessage: string | null;
  setPaySymbol: (symbol: AssetSymbol) => void;
  setReceiveSymbol: (symbol: AssetSymbol) => void;
  setPayAmount: (amount: string) => void;
  flipSymbols: () => void;
  requestQuote: () => Promise<SwapQuoteResp | null>;
  confirm: (overrides?: Partial<SwapExecReq>) => Promise<SwapExecResp | null>;
  reset: () => void;
}

export function useSwap(): UseSwapState {
  const [paySymbol, setPaySymbol] = useState<AssetSymbol>("SUI");
  const [receiveSymbol, setReceiveSymbol] = useState<AssetSymbol>("SWT");
  const [payAmount, setPayAmount] = useState<string>("");
  const [quote, setQuote] = useState<SwapQuoteResp | null>(null);
  const [loadingQuote, setLoadingQuote] = useState<boolean>(false);
  const [executing, setExecuting] = useState<boolean>(false);
  const [error, setError] = useState<WalletApiError | null>(null);

  const userMessage = useMemo(() => error?.userMessage ?? null, [error]);

  const clearError = useCallback(() => {
    setError(null);
  }, []);

  const flipSymbols = useCallback(() => {
    setPaySymbol(receiveSymbol);
    setReceiveSymbol(paySymbol);
    setQuote(null);
    clearError();
  }, [paySymbol, receiveSymbol, clearError]);

  const requestQuote = useCallback(async (): Promise<SwapQuoteResp | null> => {
    const amountValue = Number(payAmount);
    if (!payAmount || Number.isNaN(amountValue) || amountValue <= 0) {
      setQuote(null);
      return null;
    }

    setLoadingQuote(true);
    clearError();

    try {
      const data = await getSwapQuote({
        paySymbol: paySymbol as Extract<AssetSymbol, "SWT" | "SUI">,
        receiveSymbol: receiveSymbol as Extract<AssetSymbol, "SWT" | "SUI">,
        payAmount,
      });
      setQuote(data);
      return data;
    } catch (err) {
      const walletError =
        err instanceof WalletApiError
          ? err
          : new WalletApiError("견적을 받아오는 데 실패했어요.", "WALLET_UNKNOWN");
      setError(walletError);
      setQuote(null);
      return null;
    } finally {
      setLoadingQuote(false);
    }
  }, [payAmount, paySymbol, receiveSymbol, clearError]);

  const confirm = useCallback(
    async (overrides?: Partial<SwapExecReq>): Promise<SwapExecResp | null> => {
      const effectiveAmount = overrides?.payAmount ?? payAmount;
      const amountValue = Number(effectiveAmount);
      if (!effectiveAmount || Number.isNaN(amountValue) || amountValue <= 0) {
        return null;
      }

      setExecuting(true);
      clearError();

      try {
        const payload: SwapExecReq = {
          paySymbol: (overrides?.paySymbol ?? paySymbol) as Extract<AssetSymbol, "SWT" | "SUI">,
          receiveSymbol: (overrides?.receiveSymbol ?? receiveSymbol) as Extract<AssetSymbol, "SWT" | "SUI">,
          payAmount: effectiveAmount,
          slippageBps: overrides?.slippageBps ?? undefined,
          idempotencyKey: overrides?.idempotencyKey ?? maybeRandomId(),
        };

        const result = await executeSwap(payload);
        setQuote(null);
        setPayAmount("");
        return result;
      } catch (err) {
        const walletError =
          err instanceof WalletApiError
            ? err
            : new WalletApiError("스왑 실행에 실패했어요.", "WALLET_SWAP_FAILED");
        setError(walletError);
        return null;
      } finally {
        setExecuting(false);
      }
    },
    [payAmount, paySymbol, receiveSymbol, clearError]
  );

  const reset = useCallback(() => {
    setPaySymbol("SUI");
    setReceiveSymbol("SWT");
    setPayAmount("");
    setQuote(null);
    clearError();
  }, [clearError]);

  return {
    paySymbol,
    receiveSymbol,
    payAmount,
    quote,
    loadingQuote,
    executing,
    error,
    userMessage,
    setPaySymbol,
    setReceiveSymbol,
    setPayAmount,
    flipSymbols,
    requestQuote,
    confirm,
    reset,
  };
}
