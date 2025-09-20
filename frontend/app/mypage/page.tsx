export default function MyPage() {
  return (
    <div className="space-y-4 pb-24">
      <div className="flex items-center gap-3">
        <div className="h-12 w-12 rounded-full bg-white/10" />
        <div>
          <div className="text-sm">닉네임</div>
          <div className="text-xs text-white/60">0xf2abe...8b4b4</div>
        </div>
      </div>

      <div className="bg-card rounded-2xl p-4 space-y-3">
        <div className="text-sm">설정</div>
        <div className="h-px bg-white/10" />
        <button className="text-left w-full text-sm text-white/80">프로필 편집</button>
        <button className="text-left w-full text-sm text-white/80">지갑 연결</button>
        <button className="text-left w-full text-sm text-white/80">로그아웃</button>
      </div>
    </div>
  );
}