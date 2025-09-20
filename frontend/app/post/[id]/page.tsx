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

type Comment = {
  id: string;
  name: string;
  text: string;
  avatarSrc?: string;
};

const posts: Post[] = [
  {
    id: "1",
    name: "Ethan Carter",
    text:
      "Sui Ecosystem is a high-performance blockchain platform that delivers fast transactions. NFT, gaming, and DeFi projects are launching rapidly across the network. Its developer- and user-friendly environment makes it stand out.",
  },
  {
    id: "2",
    name: "Olivia Brooks",
    text:
      "Sui is built on the Move language, so smart contracts benefit from greater security and flexibility. More startups are choosing to launch their services on Sui every week.",
  },
  {
    id: "3",
    name: "Mason Wright",
    text:
      "Scale and low fees are the core goals of the Sui Ecosystem. Everyday payments and large DeFi flows can coexist efficiently, with wallets and apps focused on streamlined UX.",
  },
  {
    id: "4",
    name: "Sophia Reed",
    text:
      "Sui introduces a differentiated data model compared to other L1 blockchains. Parallel execution boosts TPS, making it compelling for game and social builders.",
  },
  {
    id: "5",
    name: "Liam Turner",
    text:
      "A vibrant community and developer ecosystem are fueling Sui’s momentum. Hackathons, grants, and partnerships help projects scale quickly while showcasing broader token utility.",
  },
  {
    id: "oh-1",
    name: "오승준",
    text: "마라 홀딩스 홀더입니다. 비트 가즈아",
    avatarSrc: "/oh-seungjun.png",
  },
  {
    id: "cooking-scallop-update",
    name: "Scallop Intern",
    text:
      "Scallop 최신 업데이트를 공유드립니다! 9월 17일 Scallop이 Bucket Protocol의 USDB 스테이블코인을 Scallop Mini Wallet과 Scallop Swap에 통합했습니다. USDB는 Bucket Protocol에서 제공하는 스테이블코인으로, Sui 체인 내 다양한 프로토콜에서 활용할 수 있습니다. 이번 통합으로 더 많은 디파이 옵션을 이용할 수 있게 되었으며, Mini Wallet에서는 USDB 보관과 관리가 가능하고 Swap에서는 다른 자산과의 효율적인 교환이 가능합니다. 이는 Scallop 생태계의 유틸리티를 확장하고 사용자 경험을 향상시키는 중요한 발전입니다.",
    avatarSrc: "/hugh-mason.png",
  },
];

const cookingComments: Comment[] = [
  { id: "cmt-1", name: "Jisoo Kim", text: "USDB integration sounds great! I want to try it in the mini wallet immediately.", avatarSrc: "/admin-kim.png" },
  { id: "cmt-2", name: "Doyun Lee", text: "If more protocols support USDB, the overall liquidity will definitely increase.", avatarSrc: "/admin-lee.png" },
  { id: "cmt-3", name: "Haneul Park", text: "Being able to swap USDB right away is super convenient.", avatarSrc: "/admin-diaz.png" },
  { id: "cmt-4", name: "Seoyeon Choi", text: "Could you also share the current fees for USDB transactions?" },
  { id: "cmt-5", name: "Minwoo Jung", text: "Does the Mini Wallet connect to any yield products when I store USDB?" },
  { id: "cmt-6", name: "Gaeun Han", text: "Thanks for summarizing everything so clearly!" },
  { id: "cmt-7", name: "Sanghyuk Yoon", text: "How much did the TVL grow after this integration?" },
  { id: "cmt-8", name: "Jiho Seo", text: "I’m curious whether USDB comes with an external guarantee." },
  { id: "cmt-9", name: "Yejin Kang", text: "How does the transaction speed feel when you use it daily?" },
  { id: "cmt-10", name: "Seunghyun Baek", text: "The Scallop Swap UI also feels nicer after the update." },
  { id: "cmt-11", name: "Arin Noh", text: "Please let us know if there’s a multi-chain rollout on the roadmap." },
  { id: "cmt-12", name: "Hajun Lee", text: "Will USDB appear instantly in the Mini Wallet token list?" },
  { id: "cmt-13", name: "Seoyun Moon", text: "An AMA about this integration would be awesome!" },
  { id: "cmt-14", name: "Dain Cho", text: "Looking forward to more collaborations between USDB and Scallop." },
];

const commentsByPost: Record<string, Comment[]> = {
  "1": [
    { id: "1-1", name: "Grace Lee", text: "Totally agree. The Sui ecosystem is growing rapidly right now." },
    { id: "1-2", name: "Daniel Park", text: "The transaction speed is fast enough that it fits gaming services perfectly." },
  ],
  "2": [
    { id: "2-1", name: "Sophie Kim", text: "Move’s focus on asset safety really helps me trust the contracts." },
    { id: "2-2", name: "Alex Choi", text: "There are plenty of builder programs, so new teams keep joining." },
    { id: "2-3", name: "Minji Han", text: "I joined a recent builder hackathon and learning Move there was fun." },
  ],
  "3": [
    { id: "3-1", name: "Kevin Park", text: "Wallets with strong UX make it easy for new users to adapt." },
  ],
  "4": [
    { id: "4-1", name: "Eunseo Lim", text: "Parallel execution and the high TPS make it ideal for game studios." },
    { id: "4-2", name: "Noah Kim", text: "The unique data model gives us more interesting design options." },
  ],
  "5": [
    { id: "5-1", name: "Jisoo Kang", text: "The community is so active that collaborating and sharing info is easy." },
  ],
  "cooking-scallop-update": cookingComments,
};

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
  const comments = commentsByPost[id] ?? [];

  return (
    <div className="relative mx-auto max-w-[420px] min-h-screen bg-white text-slate-900">
      <header className="flex h-12 items-center gap-3 border-b border-slate-200 px-4">
        <Link href="/" className="text-lg text-slate-500">
          {"<"}
        </Link>
        <div className="font-semibold">{"게시글"}</div>
      </header>

      <main className="space-y-6 p-4 pb-[176px]">
        <article className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
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
            <div className="text-sm font-semibold text-slate-900">{post.name}</div>
          </div>
          <div className="mt-3 rounded-2xl bg-white p-3 text-[15px] leading-relaxed text-slate-800">
            {post.text}
          </div>
        </article>

        <section className="space-y-3">
          <h3 className="font-semibold">{`댓글 ${comments.length}`}</h3>
          {comments.length > 0 ? (
            <div className="rounded-2xl border border-slate-200 bg-white">
              {comments.map((comment, index) => {
                const commentInitial = comment.name.charAt(0);
                return (
                  <div
                    key={comment.id}
                    className={`flex gap-3 p-4 ${index !== comments.length - 1 ? "border-b border-slate-100" : ""}`}
                  >
                    <div className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-slate-100">
                      {comment.avatarSrc ? (
                        <Image
                          src={comment.avatarSrc}
                          alt={`${comment.name} profile image`}
                          width={40}
                          height={40}
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        <span className="text-sm text-slate-500">{commentInitial}</span>
                      )}
                    </div>
                    <div className="flex-1 space-y-1">
                      <div className="text-sm font-semibold text-slate-900">{comment.name}</div>
                      <p className="text-sm leading-relaxed text-slate-700">{comment.text}</p>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="text-slate-500">{"첫 댓글을 남겨보세요."}</div>
          )}
        </section>
      </main>

      <CommentComposer className="fixed left-0 right-0 bottom-24 z-40 px-4 pb-[env(safe-area-inset-bottom)]" />
    </div>
  );
}
