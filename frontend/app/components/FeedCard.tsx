// frontend/app/components/FeedCard.tsx
"use client";

import Link from "next/link";

type Props = {
  id?: string; // id가 있으면 상세 페이지로 이동
  name: string;
  text: string;
};

export function FeedCard({ id, name, text }: Props) {
  const CardBody = (
    <div className="bg-white/5 rounded-2xl p-4 space-y-2">
      <div className="flex items-center gap-3">
        <div className="h-10 w-10 rounded-full bg-white/10" />
        <div className="text-sm">{name}</div>
      </div>

      <div className="text-sm leading-relaxed bg-white/90 text-black rounded-2xl p-3">
        {text}
      </div>

      {/* 버튼 → span 으로 바꿔서 전체 클릭 방해 제거 */}
      <div className="flex items-center gap-4 text-white/70 text-sm">
        <span>♡</span>
        <span>💬</span>
      </div>
    </div>
  );

  // id 있으면 상세 페이지 링크, 없으면 그냥 카드만
  return id ? (
    <Link href={`/post/${id}`} className="block">
      {CardBody}
    </Link>
  ) : (
    CardBody
  );
}