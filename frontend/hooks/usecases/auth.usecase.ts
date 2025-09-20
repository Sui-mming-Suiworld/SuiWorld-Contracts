"use client";

import { useCallback } from "react";

import { supabase } from "@/lib/supabase/client";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL ?? "http://localhost:8000";
const SESSION_STORAGE_KEY = "suiworld.session";

export type BackendProfile = {
  id: number;
  supabase_id: string | null;
  email: string | null;
  sui_address: string | null;
  display_name: string | null;
  avatar_url: string | null;
  session_key: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type BackendSession = {
  token: string;
  expires_at: string;
};

export type SupabaseExchangePayload = {
  profile: BackendProfile;
  session: BackendSession;
};

type ExchangeResult =
  | { success: true; data: SupabaseExchangePayload }
  | { success: false; reason: "missing-session" | "exchange-failed"; message?: string };

const persistSession = (payload: SupabaseExchangePayload) => {
  localStorage.setItem(
    SESSION_STORAGE_KEY,
    JSON.stringify({
      token: payload.session.token,
      expiresAt: payload.session.expires_at,
      profile: payload.profile,
    }),
  );
};

const isAnonymousSession = (session: Awaited<ReturnType<typeof supabase.auth.getSession>>["data"]["session"]) => {
  const provider = session?.user?.app_metadata?.provider;
  return !session?.user || provider === "anonymous" || provider === undefined;
};

export const useAuth = () => {
  const loginWithGoogle = useCallback(async () => {
    const redirectTo = `${window.location.origin}/onboarding`;
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo,
      },
    });
    if (error) {
      throw error;
    }
  }, []);

  const exchangeSupabaseSession = useCallback(async (): Promise<ExchangeResult> => {
    const { data } = await supabase.auth.getSession();
    const session = data.session;

    if (!session || isAnonymousSession(session)) {
      return { success: false, reason: "missing-session" };
    }

    const accessToken = session.access_token;
    if (!accessToken) {
      return { success: false, reason: "missing-session" };
    }

    let response: Response;
    try {
      response = await fetch(`${BACKEND_URL}/auth/supabase-login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ access_token: accessToken }),
      });
    } catch (error) {
      console.warn("Failed to reach backend for Supabase session exchange", error);
      await supabase.auth.signOut();
      localStorage.removeItem(SESSION_STORAGE_KEY);
      return { success: false, reason: "missing-session" };
    }

    let payload: unknown = null;
    try {
      payload = await response.json();
    } catch (error) {
      payload = null;
    }

    if (response.status === 401) {
      await supabase.auth.signOut();
      localStorage.removeItem(SESSION_STORAGE_KEY);
      return { success: false, reason: "missing-session" };
    }

    if (!response.ok) {
      const detail =
        typeof payload === "object" && payload !== null && "detail" in payload
          ? (payload as { detail?: string }).detail
          : undefined;
      return {
        success: false,
        reason: "exchange-failed",
        message: detail ?? "Unable to exchange Supabase session",
      };
    }

    const typedPayload = payload as SupabaseExchangePayload;
    persistSession(typedPayload);

    return { success: true, data: typedPayload };
  }, []);

  const finalizeOAuth = useCallback(async (): Promise<boolean> => {
    const currentUrl = new URL(window.location.href);
    let shouldReplaceUrl = false;

    if (currentUrl.hash.includes("access_token")) {
      const hashParams = new URLSearchParams(currentUrl.hash.slice(1));
      const accessToken = hashParams.get("access_token");
      const refreshToken = hashParams.get("refresh_token");

      if (accessToken) {
        const { error } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken ?? undefined,
        });
        if (error) {
          throw error;
        }
      }

      currentUrl.hash = "";
      shouldReplaceUrl = true;
    }

    const code = currentUrl.searchParams.get("code");
    const state = currentUrl.searchParams.get("state");
    if (code && state) {
      const { error } = await supabase.auth.exchangeCodeForSession(currentUrl.toString());
      if (error) {
        throw error;
      }
      currentUrl.searchParams.delete("code");
      currentUrl.searchParams.delete("state");
      shouldReplaceUrl = true;
    }

    if (shouldReplaceUrl) {
      window.history.replaceState({}, document.title, currentUrl.pathname + currentUrl.search);
    }

    const { data } = await supabase.auth.getSession();
    return Boolean(data.session && !isAnonymousSession(data.session));
  }, []);

  const logout = useCallback(async () => {
    await supabase.auth.signOut();
    localStorage.removeItem(SESSION_STORAGE_KEY);
  }, []);

  return {
    loginWithGoogle,
    exchangeSupabaseSession,
    finalizeOAuth,
    logout,
  };
};
