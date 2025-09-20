"use client";
import { useState } from "react";

export function SwapPanel() {
  const [pay, setPay] = useState("");
  const [recv, setRecv] = useState("");

  return (
    <div className="space-y-3">
      <SwapBox label="지불" token="ETH" value={pay} onChange={setPay} sub="0 ETH" />
      <div className="grid place-items-center">
        <button type="button" className="grid h-10 w-10 place-items-center rounded-full bg-brand-blue text-white shadow-sm">
          ⇅
        </button>
      </div>
      <SwapBox label="수령" token="SUI" value={recv} onChange={setRecv} sub="0 SUI" />
      <button
        type="button"
        className="mt-2 h-12 w-full rounded-2xl bg-brand-blue text-base font-semibold text-white transition hover:bg-blue-500 disabled:opacity-50"
      >
        Swap
      </button>
    </div>
  );
}

type SwapBoxProps = {
  label: string;
  token: string;
  value: string;
  onChange: (value: string) => void;
  sub: string;
};

function SwapBox({ label, token, value, onChange, sub }: SwapBoxProps) {
  return (
    <div className="space-y-2 rounded-2xl border border-slate-200 bg-card p-4 text-slate-900">
      <div className="text-sm font-medium text-slate-600">{label}</div>
      <div className="flex items-center gap-3">
        <input
          className="flex-1 bg-transparent text-3xl font-semibold text-slate-900 outline-none"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder="0"
        />
        <button
          type="button"
          className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-700"
        >
          <span className="grid h-4 w-4 place-items-center rounded-full bg-slate-100 text-xs text-slate-500">•</span>
          {token} ▼
        </button>
      </div>
      <div className="text-xs text-slate-500">{sub}</div>
    </div>
  );
}

