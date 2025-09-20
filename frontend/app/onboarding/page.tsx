"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { useAuth } from "@/hooks/usecases/auth.usecase";

const SESSION_STORAGE_KEY = "suiworld.session";

type Status = "idle" | "working" | "error" | "success";

type ErrorDisplay = {
  message: string;
};

// Assuming the correct ExchangeResult type looks like this
// This is not part of the file, but for your understanding
// type ExchangeResult =
//   | { success: true; profile: unknown }
//   | { success: false; reason: string; message?: string };

export default function OnboardingPage() {
  const router = useRouter();
  const { loginWithGoogle, exchangeSupabaseSession, logout } = useAuth();
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<ErrorDisplay | null>(null);

  useEffect(() => {
    const run = async () => {
      const result = await exchangeSupabaseSession();

      // Type guard: Check if the exchange was NOT successful
      if (!result.success) {
        // Now TypeScript knows result is { success: false; reason: string; message?: string }
        if ("reason" in result && result.reason === "exchange-failed") {
          setStatus("error");
          setError({
            message: result.message ?? "Failed to connect your Supabase session.",
          });
          return;
        }

        // If not 'exchange-failed', no error should be displayed
        setStatus("idle");
        setError(null);
        return;
      }

      // This block runs only if `result.success` is `true`
      setStatus("success");
      setError(null);
      setTimeout(() => router.push("/"), 800);
    };

    run().catch((err: Error) => {
      setStatus("error");
      setError({ message: err.message });
    });
  }, [exchangeSupabaseSession, router]);

  const handleGoogleLogin = async () => {
    setStatus("working");
    setError(null);
    try {
      await loginWithGoogle();
    } catch (err) {
      const message = err instanceof Error ? err.message : "Google login failed";
      setStatus("error");
      setError({ message });
    }
  };

  const handleLogout = async () => {
    await logout();
    localStorage.removeItem(SESSION_STORAGE_KEY);
    setStatus("idle");
    setError(null);
  };

  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col gap-6 px-6 py-16">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold">Welcome to SuiWorld</h1>
        <p className="text-sm text-neutral-500">
          Connect your Google account via Supabase or complete zkLogin to begin collecting SWT.
        </p>
      </header>

      <section className="space-y-3">
        <button
          onClick={handleGoogleLogin}
          className="w-full rounded-md bg-blue-600 px-4 py-3 text-white hover:bg-blue-700 disabled:opacity-50"
          disabled={status === "working"}
        >
          Continue with Google
        </button>
        <button
          onClick={() => alert("zkLogin flow coming soon")}
          className="w-full rounded-md border border-neutral-300 px-4 py-3 hover:bg-neutral-50"
          type="button"
        >
          Use zkLogin Wallet
        </button>
      </section>

      {status === "working" && (
        <p className="text-sm text-neutral-500">Finishing sign-in with Supabase...</p>
      )}

      {status === "success" && (
        <p className="text-sm text-emerald-600">You are all set! Redirecting...</p>
      )}

      {status === "error" && error && (
        <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {error.message}
        </div>
      )}

      <footer className="mt-auto space-y-2 text-sm text-neutral-500">
        <p>
          If you signed in on the wrong account you can
          <button
            className="ml-1 underline"
            onClick={handleLogout}
            type="button"
          >
            sign out and try again
          </button>
          .
        </p>
      </footer>
    </main>
  );
}