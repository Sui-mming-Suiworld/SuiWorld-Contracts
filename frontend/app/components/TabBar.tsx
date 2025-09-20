// frontend/components/TabBar.tsx
'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

export function TabBar() {
  const pathname = usePathname();
  const Item = ({ href, label, icon }: { href: string; label: string; icon: string }) => {
    const active = pathname === href;
    return (
      <Link
        href={href}
        className={`flex flex-col items-center justify-center flex-1 py-3 text-xs ${active ? "text-brand-blue" : "text-white/70"}`}
      >
        <div className={`h-6 w-6 rounded-2xl ${active ? "bg-white text-black" : "bg-white/10"} grid place-items-center mb-1`}>
          <span>{icon}</span>
        </div>
        {label}
      </Link>
    );
  };

  return (
    <div className="m-4 bg-white/10 backdrop-blur rounded-2xl px-3 flex shadow-lg">
      <Item href="/" label="Home" icon="🏠" />
      <Item href="/cooking" label="Cooking" icon="🍳" />
      <Item href="/wallet" label="Wallet" icon="👛" />
      <Item href="/mypage" label="My Page" icon="👤" />
    </div>
  );
}