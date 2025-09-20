"use client";
import { useState } from "react";

export function CommentComposer({ className = "" }: { className?: string }) {
  const [text, setText] = useState("");

  const send = () => {
    const value = text.trim();
    if (!value) return;
    console.log("comment:", value);
    setText("");
  };

  return (
    <div className={`mx-auto max-w-[420px] px-4 ${className}`}>
      <div className="flex items-center gap-2 rounded-2xl border border-slate-200 bg-white p-2 shadow-sm">
        <input
          value={text}
          onChange={(event) => setText(event.target.value)}
          placeholder="댓글을 입력해주세요"
          className="h-10 flex-1 rounded-xl bg-slate-100 px-3 text-sm text-slate-700 outline-none placeholder:text-slate-400"
        />
        <button
          onClick={send}
          className="h-10 rounded-xl bg-brand-blue px-4 text-sm font-medium text-white transition hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
          disabled={!text.trim()}
          type="button"
        >
          등록
        </button>
      </div>
    </div>
  );
}

