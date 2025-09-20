export function Chip({ label, active }: { label: string; active?: boolean }) {
  return (
    <span className={`px-3 py-1 rounded-full text-xs border ${active ? "bg-brand-blue/20 border-brand-blue" : "bg-white/10 border-white/20"}`}>
      {label}
    </span>
  );
}