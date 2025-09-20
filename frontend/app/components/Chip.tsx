'use client';

type ChipProps = {
  label: string;
  active?: boolean;
  onClick?: () => void;
};

export function Chip({ label, active = false, onClick }: ChipProps) {
  const base = 'px-3 py-1 rounded-full text-xs border transition-colors';
  const state = active
    ? 'bg-brand-blue/20 border-brand-blue text-brand-blue'
    : 'bg-white/10 border-white/20 text-white/80 hover:border-white/40';

  return (
    <button type="button" onClick={onClick} className={`${base} ${state}`}>
      {label}
    </button>
  );
}
