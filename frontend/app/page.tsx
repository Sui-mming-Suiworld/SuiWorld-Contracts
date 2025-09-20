import { Chip } from "./components/Chip";
import { FeedCard } from "./components/FeedCard";

const posts = [
  { id: "1", name: "서용원", text: "다른 종류는 없으신가요?" },
  { id: "2", name: "오승준", text: "네 이번엔 손절하고 마라만 집중하고 있습니다" },
  { id: "3", name: "서용원", text: "와 근절심하셨군요 고생하십니다" },
];

export default function HomePage() {
  return (
    <div className="space-y-4 pb-24">
      <div className="flex gap-2 flex-wrap">
        <Chip label="Developer" active />
        <Chip label="Market" />
        <Chip label="Decentralize" />
        <Chip label="other" />
      </div>

      <div className="space-y-3">
        {posts.map((p) => (
          <FeedCard key={p.id} id={p.id} name={p.name} text={p.text} />
        ))}
      </div>
    </div>
  );
}