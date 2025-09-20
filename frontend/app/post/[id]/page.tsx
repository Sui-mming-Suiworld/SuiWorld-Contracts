// app/post/[id]/page.tsx
import Image from "next/image";
import Link from "next/link";
import { CommentComposer } from "@/app/components/CommentComposer";

type Props = { params: { id: string } };

type Post = {
  id: string;
  name: string;
  text: string;
  avatarSrc?: string;
};

const posts: Post[] = [
  {
    id: "1",
    name: "Ethan Carter",
    text: "Sui Ecosystem is a high-performance blockchain platform that delivers fast transactions. NFT, gaming, and DeFi projects are launching rapidly across the network. Its developer- and user-friendly environment makes it stand out.",
  },
  {
    id: "2",
    name: "Olivia Brooks",
    text: "Sui is built on the Move language, so smart contracts benefit from greater security and flexibility. More startups are choosing to launch their services on Sui every week.",
  },
  {
    id: "3",
    name: "Mason Wright",
    text: "Scale and low fees are the core goals of the Sui Ecosystem. Everyday payments and large DeFi flows can coexist efficiently, with wallets and apps focused on streamlined UX.",
  },
  {
    id: "4",
    name: "Sophia Reed",
    text: "Sui introduces a differentiated data model compared to other L1 blockchains. Parallel execution boosts TPS, making it compelling for game and social builders.",
  },
  {
    id: "5",
    name: "Liam Turner",
    text: "A vibrant community and developer ecosystem are fueling Sui’s momentum. Hackathons, grants, and partnerships help projects scale quickly while showcasing broader token utility.",
  },
  {
    id: "oh-1",
    name: "오승준",
    text: "마라 홀딩스 홀더입니다. 비트 가즈아",
    avatarSrc: "/oh-seungjun.png",
  },
];

export default function PostDetailPage({ params }: Props) {
  const { id } = params;
  const post = posts.find((item) => item.id === id);

  if (!post) {
    return (
      <div className="p-4 text-sm text-slate-500">
        {"존재하지 않는 글입니다."}
      </div>
    );
  }

  const initials = post.name.charAt(0);

  return (
    <div className="relative mx-auto max-w-[420px] min-h-screen bg-white text-slate-900">
      <header className="flex h-12 items-center gap-3 border-b border-slate-200 px-4">
        <Link href="/" className="text-lg text-slate-500">
          {"<-"}
        </Link>
        <div className="font-semibold">{"게시글"}</div>
      </header>

      <main className="space-y-6 p-4 pb-[176px]">
        <article className="rounded-2xl border border-slate-200 bg-card p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-slate-100">
              {post.avatarSrc ? (
                <Image
                  src={post.avatarSrc}
                  alt={`${post.name} profile image`}
                  width={40}
                  height={40}
                  className="h-full w-full object-cover"
                />
              ) : (
                <span className="text-sm text-slate-500">{initials}</span>
              )}
            </div>
            <div className="font-semibold">{post.name}</div>
          </div>
          <div className="mt-3 rounded-2xl bg-white p-3 text-[15px] leading-relaxed text-slate-800">
            {post.text}
          </div>
        </article>

        <section className="space-y-3">
          <h3 className="font-semibold">{"댓글 0"}</h3>
          <div className="text-slate-500">{"첫 댓글을 남겨보세요."}</div>
        </section>
      </main>

      <CommentComposer className="fixed left-0 right-0 bottom-24 z-40 px-4 pb-[env(safe-area-inset-bottom)]" />
    </div>
  );
}
