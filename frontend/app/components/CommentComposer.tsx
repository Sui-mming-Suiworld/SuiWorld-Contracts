"use client";
import { useState } from "react";

export function CommentComposer({ className = "" }: { className?: string }) {
  const [text, setText] = useState("");

  const send = () => {
    const v = text.trim();
    if (!v) return;
    // TODO: 나중에 API 연결
    console.log("comment:", v);
    setText("");
  };

  return (
    <div className={`mx-auto max-w-[420px] px-4 ${className}`}>
      <div className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-2xl p-2 backdrop-blur">
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="댓글을 입력하세요"
          className="flex-1 h-10 px-3 rounded-xl bg-transparent outline-none text-white placeholder:text-white/40"
        />
        <button
          onClick={send}
          className="h-10 px-4 rounded-xl bg-white text-black font-medium disabled:opacity-50"
          disabled={!text.trim()}
        >
          등록
        </button>
      </div>
    </div>
  );
}