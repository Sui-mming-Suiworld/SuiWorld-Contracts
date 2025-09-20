import { Chip } from "../components/Chip";

export default function CookingPage() {
  return (
    <div className="space-y-4 pb-24">
      <div className="flex gap-2 flex-wrap">
        {["마라", "결혼", "wifi", "금리"].map((t) => <Chip key={t} label={t} />)}
      </div>
      <div className="space-y-4">
        {[1,2,3].map((i) => (
          <div key={i} className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-full bg-white/10" />
            <div className="flex-1 h-12 rounded-xl bg-white/5" />
            <div className="flex items-center gap-3 text-white/60">
              <button>♡</button>
              <button>💬</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}