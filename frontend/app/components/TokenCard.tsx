export function TokenCard(props: { icon?: React.ReactNode; name: string; price: string; sub: string; right?: string }) {
  return (
    <div className="bg-card rounded-2xl p-4 flex items-center gap-3">
      <div className="h-10 w-10 rounded-full bg-white/10 grid place-items-center">
        {props.icon ?? <span>💧</span>}
      </div>
      <div className="flex-1">
        <div className="text-sm">{props.name}</div>
        <div className="text-xs text-white/60">{props.sub}</div>
      </div>
      <div className="text-right">
        <div className="text-sm">{props.price}</div>
        <div className="text-xs text-white/60">{props.right}</div>
      </div>
    </div>
  );
}