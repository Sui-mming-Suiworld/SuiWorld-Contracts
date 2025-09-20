import type { ReactNode } from "react";

export function TokenCard(props: { icon?: ReactNode; name: string; price: string; sub: string; right?: string }) {
  return (
    <div className="flex items-center gap-3 rounded-2xl border border-slate-200 bg-card p-4 text-slate-900">
      <div className="grid h-10 w-10 place-items-center overflow-hidden rounded-full bg-white text-slate-600">
        {props.icon ?? <span>*</span>}
      </div>
      <div className="flex-1">
        <div className="text-sm font-medium text-slate-800">{props.name}</div>
        <div className="text-xs text-slate-500">{props.sub}</div>
      </div>
      <div className="text-right">
        <div className="text-sm font-medium text-slate-800">{props.price}</div>
        <div className="text-xs text-slate-500">{props.right}</div>
      </div>
    </div>
  );
}
