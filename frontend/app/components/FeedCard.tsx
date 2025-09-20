export function FeedCard({ name, text }: { name: string; text: string }) {
  return (
    <div className="bg-white/5 rounded-2xl p-4 space-y-2">
      <div className="flex items-center gap-3">
        <div className="h-10 w-10 rounded-full bg-white/10" />
        <div className="text-sm">{name}</div>
      </div>
      <div className="text-sm leading-relaxed bg-white/90 text-black rounded-2xl p-3">
        {text}
      </div>
      <div className="flex items-center gap-4 text-white/70 text-sm">
        <button>♡</button>
        <button>💬</button>
      </div>
    </div>
  );
}