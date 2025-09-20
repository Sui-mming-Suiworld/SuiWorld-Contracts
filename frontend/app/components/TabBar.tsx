// frontend/components/TabBar.tsx
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

export function TabBar() {
  const pathname = usePathname();
  const Item = ({ href, label, icon }: { href: string; label: string; icon: string }) => {
    const active = pathname === href;
    return (
      <Link
        href={href}
        className={`flex flex-1 flex-col items-center justify-center py-3 text-xs font-medium transition ${
          active ? "text-brand-blue" : "text-slate-500 hover:text-slate-700"
        }`}
      >
        <div
          className={`mb-1 grid h-6 w-6 place-items-center rounded-2xl ${
            active ? "bg-brand-blue text-white" : "bg-slate-100 text-slate-500"
          }`}
        >
          <span>{icon}</span>
        </div>
        {label}
      </Link>
    );
  };

  return (
    <div className="mx-4 flex rounded-2xl border border-slate-200 bg-white px-3 shadow-sm">
      <Item href="/" label="Home" icon="H" />
      <Item href="/cooking" label="Cooking" icon="C" />
      <Item href="/wallet" label="Wallet" icon="W" />
      <Item href="/mypage" label="My Page" icon="P" />
    </div>
  );
}
