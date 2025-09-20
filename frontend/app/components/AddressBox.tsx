"use client";
import { useState } from "react";

export function AddressBox() {
  const [addr] = useState("0xf2abe...8b4b4");
  return (
    <div className="space-y-3">
      <div className="bg-card rounded-2xl p-3 flex items-center justify-between">
        <span className="text-sm">{addr}</span>
        <button
          className="px-3 py-1 rounded-xl bg-white/10 text-sm"
          onClick={() => navigator.clipboard?.writeText(addr)}
        >
          복사
        </button>
      </div>
      <div className="rounded-2xl bg-white grid place-items-center aspect-square">
        {/* 실제 QR은 추후 이미지/컴포넌트로 교체 */}
        <span className="text-black font-semibold">QR</span>
      </div>
    </div>
  );
}