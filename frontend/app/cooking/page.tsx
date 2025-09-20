import { Chip } from "../components/Chip";
import { FeedCard } from "../components/FeedCard";

export default function CookingPage() {
  return (
    <div className="space-y-4 pb-24">
      <div className="flex flex-wrap gap-2">
        {["마라", "결혼", "wifi", "금리"].map((tag) => (
          <Chip key={tag} label={tag} />
        ))}
      </div>

      <div className="divide-y divide-slate-200">
        <div className="py-3 first:pt-0 last:pb-0">
          <FeedCard
            id="cooking-scallop-update"
            name="Scallop Intern"
            text="Scallop 최신 업데이트를 공유드립니다! 9월 17일 Scallop이 Bucket Protocol의 USDB 스테이블코인을 Scallop Mini Wallet과 Scallop Swap에 통합했습니다. USDB는 Bucket Protocol에서 제공하는 스테이블코인으로, Sui 체인 내 다양한 프로토콜에서 활용할 수 있습니다. 이번 통합으로 더 많은 디파이 옵션을 이용할 수 있게 되었으며, Mini Wallet에서는 USDB 보관과 관리가 가능하고 Swap에서는 다른 자산과의 효율적인 교환이 가능합니다. 이는 Scallop 생태계의 유틸리티를 확장하고 사용자 경험을 향상시키는 중요한 발전입니다."
            avatarSrc="/hugh-mason.png"
            avatarAlt="Hugh Mason profile image"
            initialLikes={57}
            initialComments={14}
            showOptionsMenu
            showCornerMark
          />
        </div>
      </div>
    </div>
  );
}
