// app/post/[id]/page.tsx
import { CommentComposer } from "@/app/components/CommentComposer";

type Props = { params: { id: string } };

export default function PostDetailPage({ params }: Props) {
  const { id } = params;

  const posts = [
    { id: "1", author: "서용원", content: "다른 종류는 없으신가요?" },
    { id: "2", author: "오승준", content: "네 이번엔 손절하고 마라만 집중하고 있습니다" },
    { id: "3", author: "서용원", content: "와 근절심하셨군요 고생하십니다" },
  ];
  const post = posts.find(p => p.id === id);

  if (!post) return <div className="p-4">존재하지 않는 글입니다.</div>;

  return (
    <div className="relative mx-auto max-w-[420px] min-h-screen bg-[#0A0A0A] text-white">
      <header className="px-4 h-12 flex items-center gap-3 border-b border-white/10">
        <a href="/" className="text-white/70">←</a>
        <div className="font-semibold">게시글</div>
      </header>

      {/* 탭바 + 입력창에 가리지 않도록 충분한 패딩 */}
      <main className="p-4 space-y-6 pb-[176px]">
        <article className="bg-white/5 rounded-2xl p-4">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-full bg-white/10" />
            <div className="font-semibold">{post.author}</div>
          </div>
          <div className="mt-3 text-[15px] bg-white/90 text-black rounded-2xl p-3">
            {post.content}
          </div>
        </article>

        <section className="space-y-3">
          <h3 className="font-semibold">댓글 0</h3>
          <div className="text-white/50">첫 댓글을 남겨보세요.</div>
        </section>
      </main>

      {/* ✅ 함수 prop 없이, 탭바 위에 고정 */}
      <CommentComposer className="fixed left-0 right-0 bottom-24 z-40 pb-[env(safe-area-inset-bottom)]" />
    </div>
  );
}