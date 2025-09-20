import { Chip } from "./components/Chip";
import { FeedCard } from "./components/FeedCard";

const posts = [
  {
    id: "1",
    name: "Ethan Carter",
    text: "Sui Ecosystem is a high-performance blockchain platform with impressively fast transactions. NFT, gaming, and DeFi builders are shipping products quickly thanks to the developer-friendly environment.",
    likes: 4,
    comments: 2,
  },
  {
    id: "2",
    name: "Olivia Brooks",
    text: "Because Sui is built on the Move language, smart contracts gain stronger asset security and flexibility. More startups are launching services on Sui every week.",
    likes: 5,
    comments: 3,
  },
  {
    id: "3",
    name: "Mason Wright",
    text: "Scalability and low fees let the Sui Ecosystem cover everyday payments and large DeFi trades in parallel. Wallets and apps that focus on UX stand out across the network.",
    likes: 3,
    comments: 1,
  },
  {
    id: "4",
    name: "Sophia Reed",
    text: "Sui introduces a differentiated data model compared to many L1 chains. Parallel execution dramatically boosts TPS, making it attractive for game and social developers.",
    likes: 6,
    comments: 2,
  },
  {
    id: "5",
    name: "Liam Turner",
    text: "Community programs, grants, and partnerships are fueling rapid growth. As projects scale, the utility of the Sui token keeps expanding.",
    likes: 2,
    comments: 1,
  },
];

export default function HomePage() {
  return (
    <div className="space-y-4 pb-24">
      <div className="flex flex-wrap gap-2">
        <Chip label="Developer" active />
        <Chip label="Market" />
        <Chip label="Decentralize" />
        <Chip label="Other" />
      </div>

      <div className="divide-y divide-slate-200">
        {posts.map((post) => (
          <div key={post.id} className="py-3 first:pt-0 last:pb-0">
            <FeedCard
              id={post.id}
              name={post.name}
              text={post.text}
              initialLikes={post.likes}
              initialComments={post.comments}
              showOptionsMenu
              showCornerMark
            />
          </div>
        ))}
      </div>
    </div>
  );
}

