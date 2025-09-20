export function Chip({ label, active }: { label: string; active?: boolean }) {
  return (
    <span
      className={`rounded-full border px-3 py-1 text-xs font-medium ${
        active
          ? "border-brand-blue bg-brand-blue/10 text-brand-blue"
          : "border-slate-200 bg-slate-100 text-slate-600"
      }`}
    >
      {label}
    </span>
  );
}
