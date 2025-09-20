// frontend/app/layout.tsx
import type { Metadata } from "next";
import "./globals.css";
import { TabBar } from "./components/TabBar";

export const metadata: Metadata = {
  title: "SuiWorld Web",
  description: "SuiWorld dApp Web",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body className="min-h-screen text-white">
        <div className="mx-auto max-w-[420px] min-h-screen flex flex-col relative">
          <header className="p-4 flex items-center gap-3">
            <div className="h-8 w-8 rounded-full bg-brand-blue/20 grid place-items-center">
              <div className="h-4 w-4 rounded-full bg-brand-blue" />
            </div>
            <div className="flex-1">
              <div className="rounded-full bg-card flex items-center pr-2 pl-3 h-10">
                <input className="bg-transparent flex-1 outline-none text-sm" placeholder="Value" />
                <button className="text-sm opacity-60">✕</button>
              </div>
            </div>
          </header>

          <main className="flex-1 px-4">{children}</main>

          <nav className="sticky bottom-0 inset-x-0">
            <div className="mx-auto max-w-[420px]">
              <TabBar />
            </div>
          </nav>
        </div>
      </body>
    </html>
  );
}