// frontend/app/components/FeedCard.tsx
"use client";

import { useState, type MouseEvent, type ReactNode } from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import Link from "next/link";

type Props = {
  id?: string; // when the id exists we enable detail navigation
  name: string;
  text: string;
  avatarSrc?: string;
  avatarAlt?: string;
  footer?: ReactNode;
  initialLikes?: number;
  initialComments?: number;
  onCommentClick?: () => void;
  showOptionsMenu?: boolean;
  showCornerMark?: boolean;
};

export function FeedCard({
  id,
  name,
  text,
  avatarSrc,
  avatarAlt,
  footer,
  initialLikes = 3,
  initialComments = 1,
  onCommentClick,
  showOptionsMenu = false,
  showCornerMark = false,
}: Props) {
  const router = useRouter();
  const [liked, setLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(initialLikes);

  const likeIconSrc = liked ? "/like-clicked.png" : "/like.png";
  const commentIconSrc = "/comment.png";
  const commentCount = initialComments;

  const handleLikeClick = (event: MouseEvent<HTMLButtonElement>) => {
    event.preventDefault();
    event.stopPropagation();
    const delta = liked ? -1 : 1;
    setLikeCount((count) => {
      const nextCount = Math.max(0, Math.min(count + delta, 9));
      return nextCount;
    });
    setLiked((previous) => !previous);
  };

  const handleCommentClick = (event: MouseEvent<HTMLButtonElement>) => {
    event.preventDefault();
    event.stopPropagation();
    if (id) {
      router.push(`/post/${id}`);
      return;
    }
    if (onCommentClick) {
      onCommentClick();
    }
  };

  const footerContent =
    footer !== undefined ? (
      footer
    ) : (
      <div className="flex items-center gap-6 pl-3 pr-4 text-sm text-slate-500">
        <div className="flex items-center gap-6">
          <button
            type="button"
            onClick={handleLikeClick}
            className="flex items-center gap-2 text-slate-600 transition hover:text-slate-800"
            aria-label="Toggle like"
          >
            <Image src={likeIconSrc} alt="Like" width={20} height={20} className="h-5 w-5" />
            <span>{likeCount}</span>
          </button>
          <button
            type="button"
            onClick={handleCommentClick}
            className="flex items-center gap-2 text-slate-600 transition hover:text-slate-800"
            aria-label="Open comments"
          >
            <Image src={commentIconSrc} alt="Comments" width={20} height={20} className="h-5 w-5" />
            <span>{commentCount}</span>
          </button>
        </div>
        {showCornerMark ? (
          <Image
            src="/mark.png"
            alt="Decorative mark"
            width={24}
            height={24}
            className="ml-auto h-6 w-6 object-contain translate-x-[2px]"
          />
        ) : null}
      </div>
    );

  const cardClassName = "relative rounded-2xl bg-white p-4 space-y-2 text-slate-900";

  const CardBody = (
    <div className={cardClassName}>
      <div className="flex items-center justify-between gap-3">
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
          <div className="text-sm font-bold text-slate-900">{name}</div>
        </div>
        {showOptionsMenu ? (
          <span
            className="text-lg font-semibold text-slate-400 leading-none"
            aria-hidden="true"
          >
            ···
          </span>
        ) : null}
      </div>

      <div className="rounded-2xl bg-white p-3 text-sm leading-relaxed text-slate-800">
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
