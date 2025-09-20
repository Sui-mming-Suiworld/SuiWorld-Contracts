"use client";
import { useState } from "react";

export function AddressBox() {
  const [addr] = useState("0xf2abe...8b4b4");
  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between rounded-2xl border border-slate-200 bg-card p-3 text-slate-900">
        <span className="text-sm font-medium text-slate-700">{addr}</span>
        <button
          className="rounded-xl bg-white px-3 py-1 text-sm font-medium text-slate-600 transition hover:text-slate-800"
          onClick={() => navigator.clipboard?.writeText(addr)}
          type="button"
        >
          복사
        </button>
      </div>
      <div className="grid aspect-square place-items-center rounded-2xl border border-slate-200 bg-white text-slate-900">
        <span className="font-semibold">QR</span>
      </div>
    </div>
  );
}
