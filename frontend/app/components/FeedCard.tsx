// frontend/app/components/FeedCard.tsx
"use client";

import type { ReactNode } from "react";
import Image from "next/image";
import Link from "next/link";

type Props = {
  id?: string; // when the id exists we enable detail navigation
  name: string;
  text: string;
  avatarSrc?: string;
  avatarAlt?: string;
  footer?: ReactNode;
};

export function FeedCard({ id, name, text, avatarSrc, avatarAlt, footer }: Props) {
  const footerContent =
    footer !== undefined ? (
      footer
    ) : (
      <div className="flex items-center gap-4 text-sm text-slate-500">
        <span>Like</span>
        <span>Comment</span>
      </div>
    );

  const CardBody = (
    <div className="rounded-2xl bg-slate-100 p-4 space-y-2 text-slate-900">
      <div className="flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-white">
          {avatarSrc ? (
            <Image
              src={avatarSrc}
              alt={avatarAlt ?? `${name} profile image`}
              width={40}
              height={40}
              className="h-full w-full object-cover"
            />
          ) : (
            <span className="text-sm font-medium text-slate-500">{name.slice(0, 1)}</span>
          )}
        </div>
        <div className="text-sm font-medium text-slate-700">{name}</div>
      </div>

      <div className="rounded-2xl bg-white p-3 text-sm leading-relaxed text-slate-800 shadow-sm">
        {text}
      </div>

      {footerContent}
    </div>
  );

  // Link to the detail page only when id exists
  return id ? (
    <Link href={`/post/${id}`} className="block">
      {CardBody}
    </Link>
  ) : (
    CardBody
  );
}
