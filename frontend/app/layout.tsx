// frontend/app/layout.tsx
import type { Metadata } from "next";
import "./globals.css";
import Image from "next/image";
import { TabBar } from "./components/TabBar";

export const metadata: Metadata = {
  title: "SuiWorld Web",
  description: "SuiWorld dApp Web",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body className="min-h-screen bg-white text-slate-900 antialiased">
        <div className="relative mx-auto flex min-h-screen max-w-[420px] flex-col bg-white">
          <header className="flex items-center gap-3 border-b border-slate-200 p-4">
            <Image
              src="/sui-world-letter.png"
              alt="SuiWorld lettering"
              width={120}
              height={32}
              className="h-8 w-auto"
              priority
            />
            <Image
              src="/sui-world-logo.png"
              alt="SuiWorld logo"
              width={48}
              height={48}
              className="h-10 w-10"
              priority
            />
            <div className="flex-1">
              <div className="flex h-10 items-center rounded-full border border-slate-200 bg-white px-3 shadow-sm">
                <input
                  className="flex-1 bg-transparent text-sm text-slate-700 outline-none placeholder:text-slate-400"
                  placeholder="Value"
                />
                <button
                  className="text-sm text-slate-400 transition hover:text-slate-600"
                  type="button"
                  aria-label="검색어 지우기"
                >
                  ×
                </button>
              </div>
            </div>
          </header>

          <main className="flex-1 px-4 py-4">{children}</main>

          <nav className="sticky inset-x-0 bottom-0 bg-white/90 pb-4 pt-2 backdrop-blur">
            <div className="mx-auto max-w-[420px]">
              <TabBar />
            </div>
          </nav>
        </div>
      </body>
    </html>
  );
}
