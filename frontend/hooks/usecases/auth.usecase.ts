"use client";

import { useCallback } from "react";

import { supabase } from "@/lib/supabase/client";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL ?? "http://localhost:8000";
const SESSION_STORAGE_KEY = "suiworld.session";

type ExchangeResult =
  | { success: true; profile: unknown }
  | { success: false; reason: "missing-session" | "exchange-failed"; message?: string };

export const useAuth = () => {
  const loginWithGoogle = useCallback(async () => {
    const redirectTo = `${window.location.origin}/onboarding`;
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo },
    });
    if (error) {
      throw error;
    }
  }, []);

  const exchangeSupabaseSession = useCallback(async (): Promise<ExchangeResult> => {
    const { data } = await supabase.auth.getSession();
    const session = data.session;
    const accessToken = session?.access_token;

    if (!accessToken) {
      return { success: false, reason: "missing-session" };
    }

    const response = await fetch(`${BACKEND_URL}/auth/supabase-login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ access_token: accessToken }),
    });

    const payload = await response.json();
    if (!response.ok) {
      return {
        success: false,
        reason: "exchange-failed",
        message: payload?.detail ?? "Unable to exchange Supabase session",
      };
    }

    localStorage.setItem(
      SESSION_STORAGE_KEY,
      JSON.stringify({
        token: payload.session.token,
        expiresAt: payload.session.expires_at,
        profile: payload.profile,
      }),
    );

    return { success: true, profile: payload.profile };
  }, []);

  const logout = useCallback(async () => {
    await supabase.auth.signOut();
    localStorage.removeItem(SESSION_STORAGE_KEY);
  }, []);

  return {
    loginWithGoogle,
    exchangeSupabaseSession,
    logout,
  };
};
