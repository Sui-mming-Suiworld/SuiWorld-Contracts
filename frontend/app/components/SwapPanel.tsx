"use client";
import { useState } from "react";

export function SwapPanel() {
  const [pay, setPay] = useState("");
  const [recv, setRecv] = useState("");

  return (
    <div className="space-y-3">
      <SwapBox label="지불" token="ETH" value={pay} onChange={setPay} sub="0 ETH" />
      <div className="grid place-items-center">
        <button className="h-10 w-10 rounded-full bg-brand-blue grid place-items-center">🔃</button>
      </div>
      <SwapBox label="수령" token="SUI" value={recv} onChange={setRecv} sub="0 SUI" />
      <button className="mt-2 w-full h-12 rounded-2xl bg-brand-blue text-black font-semibold">Swap</button>
    </div>
  );
}

function SwapBox({
  label, token, value, onChange, sub,
}: { label: string; token: string; value: string; onChange: (v: string) => void; sub: string }) {
  return (
    <div className="bg-card rounded-2xl p-4 space-y-2">
      <div className="text-sm text-white/70">{label}</div>
      <div className="flex items-center gap-3">
        <input
          className="bg-transparent text-3xl outline-none flex-1"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="0"
        />
        <button className="rounded-xl bg-white/10 px-3 py-2 text-sm flex items-center gap-2">
          <span className="h-4 w-4 rounded-full bg-white/20 grid place-items-center">◆</span>
          {token} ▾
        </button>
      </div>
      <div className="text-xs text-white/50">{sub}</div>
    </div>
  );
}