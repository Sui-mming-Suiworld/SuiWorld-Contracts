// frontend/components/TabBar.tsx
"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";

export function TabBar() {
  const pathname = usePathname();
  const Item = ({
    href,
    label,
    iconBase,
    iconScale = 1,
  }: {
    href: string;
    label: string;
    iconBase: string;
    iconScale?: number;
  }) => {
    const active = pathname === href;
    const iconSrc = `/${iconBase}${active ? "-blue" : ""}.png`;
    const imageStyle = iconScale !== 1 ? { transform: `scale(${iconScale})` } : undefined;
    return (
      <Link
        href={href}
        className={`flex flex-1 flex-col items-center justify-center py-3 text-xs font-medium transition ${
          active ? "text-brand-blue" : "text-slate-500 hover:text-slate-700"
        }`}
      >
        <div className="relative mb-1 flex h-6 w-6 items-center justify-center">
          <Image
            src={iconSrc}
            alt={`${label} icon`}
            fill
            className="object-contain"
            sizes="24px"
            style={imageStyle}
          />
        </div>
        {label}
      </Link>
    );
  };

  return (
    <div className="mx-4 flex rounded-2xl border border-slate-200 bg-white px-3 shadow-sm">
      <Item href="/" label="Home" iconBase="home" />
      <Item href="/cooking" label="Cooking" iconBase="cooking" iconScale={0.85} />
      <Item href="/wallet" label="Wallet" iconBase="wallet" />
      <Item href="/mypage" label="My Page" iconBase="my-page" iconScale={0.85} />
    </div>
  );
}
