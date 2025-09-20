페이지별 Feature 리스트 (갤러리 제거판)

1) Home (피드 + 태그/검색)

- 홈 버튼: 루트 이동 **Check**

- 검색바: 키워드(제목/본문/태그) 검색 **Check**

- 태그 필터: 다중 선택 가능(OR/AND 추후 옵션) **Check**

무한 스크롤 피드: 최신/핫 정렬(좋아요·알럿 가중치 반영) **정렬 버튼 필요**

포스트 카드: 본문 프리뷰, 태그 칩, 좋아요/알럿 수, 상태 뱃지(NORMAL/HYPED/UNDER_REVIEW) **like, alert 숫자 위치, 뱃지 구현 필요**

상세 이동: 카드/본문 클릭 → Message Detail **checked**

좋아요 토글: message_likes **checked**

알럿(신고) 토글: message_alerts (중복 방지) **checked**

상태 전환 표시: 좋아요 20↑/알럿 20↑ 시 자동 UNDER_REVIEW → 투표 통과 시 HYPED/SPAM (규칙 유지). **checked**

핫 댓글 2개 프리뷰: 최신 2 + 좋아요 상위 2 노출 **checked**

2) Message Detail (/message/[id])

본문/미디어 표시, 태그 목록 **checked**

좋아요/알럿 토글 + 카운트 갱신 **checked**

댓글 영역: 작성/수정/삭제, 정렬(최신/좋아요순) **정렬버튼 필요**

상태 뱃지: NORMAL/UNDER_REVIEW/HYPED/SPAM/DELETED **뱃지 구현 필요**

업데이트 권한: (예: 본문 수정/태그 수정) **이거 필요 없지 않을까요 ex. X무료버전**

서버가 온체인으로 SWT ≥ 1000 확인 또는 전역 매니저 NFT 보유 시 허용(기존 U 규칙 유지 해석). **checked**

삭제 권한: 전역 매니저 NFT 보유자만 허용(기존 D 규칙 유지). **checked**

제안/투표 현황 표시: 관련 Proposal 상태/득표 수 **checked**

3) Compose / Edit (/compose) **아직 화면 없음**

작성 폼: 제목/본문/이미지, 태그 입력(다중) **checked**

작성 권한(UI+서버): 온체인 SWT ≥ 1000 충족 시만 허용(작성 C 규칙 유지). **checked**

해시 계산 & 앵커(선택): 본문/파일 해시 → 온체인 앵커 tx (실패 시 재시도) **checked**

작성 성공 이동: 상세 페이지 **checked**

4) Vote / Manager Console (/manager) **아직 화면 없음**

내 매니저 여부: 전역 Manager NFT 소유 확인 **checked**

심사 대기 목록: 좋아요 20↑(HYPE 후보)/알럿 20↑(SCAM 후보)로 열린 OPEN Proposals **checked**

투표: 12명 중 1명으로 찬성/반대 서명(중복 불가) **checked**

쿼럼/현황 표시: 찬성/반대/잔여, 필요 찬성 4인 **checked**

Resolve: 4인 이상 찬성 시 통과 처리 → **+ 4인 이상 반대가 먼저 될 시 reject 처리**

HYPE: 창작자 +100 SWT, 매니저 +10 SWT **checked**

SCAM: 창작자 -200 SWT, 매니저 +10 SWT **checked**

집행 tx digest 및 payouts/tx_logs 기록, 메시지 상태 갱신(HYPED 또는 SPAM/DELETED) **checked**

Misjudgement(후속): 전원 투표 후 BFT 모델로 오판 검사 → 잦은 오판 시 매니저 NFT 슬래시·교체(표시). **checked**

5) Swap (/swap)

SUI↔SWT 고정가 스왑(최소): 견적, 사용자 서명, swaps/tx_logs 기록 **checked**

잔액 표시: SUI/SWT **checked**

SWT 발행/풀 설정: 팀 트레저리 30%, 풀 70% 초기화(데브넷 스크립트) **checked**

6) My Page (/me)

프로필 보기/수정: 이미지, 닉네임, 소개 **checked**

내 글/댓글/좋아요한 글 목록 **checked**

내 제안/투표 내역(매니저인 경우) **checked**

내 보상/슬래싱 기록: payouts/tx_logs 타임라인 **checked, randomly airdrop (for cooking messages)도 표현 필요**

7) Auth (/auth) 

zkLogin 온보딩: OIDC → ZK Proof → 서버 세션 교환 **checked**

지갑 주소 연동: users.wallet_address 검증/등록 **checked, 타 체인은 일단 구현 X?**