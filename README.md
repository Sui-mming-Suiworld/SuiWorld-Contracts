A SocialFi platform on the Sui blockchain.
=======
## SSSS (Super Simple Summary for SuiWorld)

- SuiWorld는 Sui 블록체인 위에서 고퀄리티 인텔의 생산·검증·보상을 선순환시키는 SocialFi 플랫폼입니다. zkLogin 기반의 쉬운 온보딩과 피드 중심 UX를 제공하고, SWT 토크노믹스로 글 작성·리뷰·투표 등 기여를 정량화 하여 보상/페널티를 자동화합니다. Manager NFT를 보유한 12명의 커뮤니티 매니저가 온체인 투표로 메세지를 하이프/스캠으로 분류해 품질을 관리하며, SUI<>SWT 스왑과 Wormhole NTT 연동으로 유동성과 에어드롭 리워드를 제공합니다. 프론트엔드(Next.js)–백엔드(FastAPI)–DB(PostgreSQL)–Move 모듈 아키텍처로 구성되어, Yaps 기반 InfoFi의 한계를 해결하고 지속 가능한 정보 생태계를 지향합니다.


## Problem Solving of InfoFi Product
### Cons of Yaps

1. 정보의 무덤(SNS를 통한 양질의 정보 접근 경로 삭제)
    - X 등 SNS에서 Yapper들의 단순 가공 정보들의 무작위적 확산으로 인해, X를 통한 양질의 정보 습득에 있어 Customer의 스트레스 상승
2. 생태계와 무관함
    - 온체인 활동·평판과 단절되어 기여가 생태계 성장으로 발전하기 어려움
    - Yapping Event가 종료될 시 장기적인 커뮤니티 축적 불가
3. 전문 Yapper로 인한 마케팅 효율 감소
    - Kaito Dashboard, Inner Circle 등 소수의 인플루언서 중심 확산은 비용 대비 전환율이 낮음
    - 단기 노출은 가능해도 지속 가능한 신뢰 형성 한계

### Suggestion of SuiWorld

1. Sui 네트워크 위에서 작동하는 SocialFi
    - 지갑/인증과 활동 기록을 Sui에 연결, 양질의 정보 생산 및 관련 활동이 Sui 생태계의 하나의 트랜잭션으로써 네트워크 활성화에 기여할 수 있도록 제시
2. 양질의 정보를 작성하도록, 그리고 자발적으로 관리하도록 유도하는 incentive Tokenomics
    - SWT 보유 여부에 따른 글 작성 및 상호작용 권한 제공
    - Manager를 통해 양질의 글을 구별하고, 이에 명확한 보상/징계를 부여
3. 일반 Customer들에게 친숙한 UI/UX의 제공을 통한 신규 생태계 유입 유도
    - zkLogin 등을 활용, New Customer에게 친숙한 접근 제안
    - thread-like, mobile friendly UI/UX를 바탕으로 접근성 제공

## Architecture Diagrams

Rough Guide

```text
[ User ]
    |
    v
[ Frontend (Next.js) ] <--> [ Backend (FastAPI) ] <--> [ Database (PostgreSQL)]
                                      |
                                      v
                        [ Sui Blockchain (Move Modules) ]
```

## Stack 

### Frontend
 - 
### Backend
 - 
### Onchain Metric (Sui Move)
 - 
## Features of our product

### Onboarding with zkLogin

 - zkLogin 기반 무시드(Seedless) 지갑 온보딩으로 클릭 한 번에 시작.
 - 지갑과 프로필(이미지, ID, 소개) 연동으로 계정 식별과 소셜 기능 활성화.
 - 필요 기능 : zkLogin

### SWT(SuiWorld Token) Tokenmoics

 - 총 100,000,000 SWT 발행: 30% Treasury, 70% 유동성/풀 배분.
 - 온체인 SUI<>SWT 스왑 풀을 통해 자산 유입·유출 및 유동성 공급.
 - 필요 기능 : SUI<>SWT Swap
#### 왜 SUI를 그대로 사용하지 않는가?
 - 이 아이템을 제작하며 차용한 기존 Web2 프로덕트는 바로 싸이월드(Cyworld)였음.
 - 싸이월드는 '도토리'라는 재화를 원화를 통해 구입한 뒤, 이를 바탕으로 플랫폼 내에서 각종 기능들을 결제할 수 있었음. 반대로 도토리를 원화로 전환하는 것도 가능.
 - 현재 SuiWorld는 token swap에 기반한 금전적 요소 활용만을 제공하지만, Further Improvement 요소 개발을 위한 재화로써 SWT를 둠으로 프로젝트 확장을 기대할 수 있음. 

### Home Message(Feed) & Search
 - 홈 피드가 메인 화면이며 메시지 목록, 정렬/필터, 검색을 제공.
 - 메시지 CRUD 정책: 작성/수정은 ≥1000 SWT 필요, 조회는 무료, 삭제는 매니저 권한.
 - 상태 흐름: NORMAL → UNDER_REVIEW → HYPED/SPAM/DELETED로 관리.
 - 정렬: 최신, 좋아요수, 경고수 및 검토중(UNDER_REVIEW) 필터 제공.
 - 필요기능 : CRUD func for Massage, Massage reaction


### Powerful Community Managers (Key Point of SuiWorld)
 - 12명의 Community Manager 존재 (Manager NFT 보유자)
 - 초기 Community manager는 Sui의 이해관계자 중 희망자에게 Airdrop.
 - Community Manager Candidate에 대한 리스트 보유.
 - 매니저는 커뮤니티 내 메세지들에 대한 수정/Vote 권한 보유. 메세지 Vote에 따른 보상 제공
 - Manager NFT 는 Marketplace에서 Tradable함. (Not Soulbound)
 - 필요 기능 : Manager NFT Mint
 
 #### 왜 이러한 형식의 관리를 진행하는가. (양질의 커뮤니티 서비스를 위한 운영 방식 고민)
 - GPT-Generated, Surf 기반 Meaningless한 메시지. 스캠 광고 등을 검열할 존재의 필요
 - 다만 이를 유저 전체 투표, Token holding 비례 등을 활용하게 될 시 고래들에 의한 커뮤니티 중립성, 퀄리티 등 훼손 가능
 - 중앙화 요소를 보유하게 되더라도, 초기 Manager에 있어 Sui 생태계의 성장을 기대하는 이해관계자들에게 제공.
 - 다만, NFT 거래를 통하여 강력하게 프로젝트에 참여하고자 하는 유저 참여 가능
 - 초기 설정의 중앙화 but 시장 거래를 통한 외부 참여를 허용하는 것
 - 이 경우 NFT 가치 훼손/프로젝트의 영향력 훼손을 막기 위해 커뮤니티 장악에 대한 자정작용이 수행될 것 기대
 - 그렇지 않은 경우를 위하여, Manager Resolve(매니저 간 악의적 관리자 투표)를 통하여 권한 박탈 기능 구현.(추후 설명)
 - 이를 위해 Manager Candidate list를 보유, NFT가 burn 되는 경우 차기 Candidate에게 Manager NFT Mint

### Message Vote (Review)
 - 좋아요 20개 이상 누적 시 12명의 매니저 투표(승격 여부) 개시.
    - 선착순 4인의 동의 시 메세지 승격. 4인의 거절 시 메세지 유지.
 - 경고 20개 이상 누적 시 12명의 매니저 투표(삭제 여부) 개시.
    - 선착순 4인의 동의 시 메세지 삭제. 4인의 거절 시 메세지 유지.
 - 투표 결과에 따라 승격(Hyped)·삭제·기각 처리 및 보상/패널티 즉시 반영.
    - 인센티브: 메세지 하이프 승격 시 크리에이터 +100 SWT, 투표에 참여한 매니저 +10 SWT.
    - 패널티: 메세지 스캠 삭제 시 크리에이터 -200 SWT, 투표에 참여한 매니저 +10 SWT 보상.
 - 필요 기능 : Vote for hype/scam with token transfer

### Manager Resolve
 - 악의적인 매니저를 관리하기 위한 기능.
 - 매니저 간 BFT 모델 투표로 고의적 오판 여부 검증.
 - 반복 오판 시 슬래시: Manager NFT 소각 및 차기 후보에게 신규 발행.
 - 필요 기능 : BFT Vote, NFT Burn and Mint 

### NTT Token Transfer and swap, Airdrop (with Wormhole NTT)
 - 멀티체인 NTT 연동으로 ETH/SOL 등 네이티브 토큰 입금 지원.
 - 네이티브 → SUI 브릿지 후 SUI<>SWT 스왑으로 제품 내 경제권 편입. (NTT<>SWT 토큰 스왑과 동일 결과)
 - 주간 리워드: ‘Cooking’(Hyped) 메시지 작성자에게 NTT 토큰 랜덤 에어드랍.
 - 필요 기능: Wormhole NTT API 호출, ETH<>SUI·SOL<>SUI 스왑, 에어드랍 자동화.


## User Journey of SuiWorld (User, Manager)
### User
- zkLogin을 통한 월렛 생성 > 프로필 생성 > SUI 전송 > SUI<>SWT Swap > 메세지 작성/상호작용 등 수행 > 다수의 Like 받을 시 Under-Review 전환 > Review 결과에 따른 보상 제공 > NTT Token Random Airdrop 당첨
### Manager
- (Manager NFT 보유자) > Mypage에서 Under-review 상태의 메세지들 검토 및 투표 > 투표 보상 제공 > (if) 커뮤니티 활동 중 악의적인 Manager의 행위 발견 시 Resolve 신청 및 투표 
## Local Runs
- 
## Further Improvement Things
- More Effective Tokenomics : SWT token burn 등 지속가능한 수준에서의 토큰 공급량을 감소 시킬 수 있는 요인 제시(SWT Holder 가치 향상)
- Add Varius SWT<>items pair : SWT token의 활용도 향상을 위한 커뮤니티 내 아이템/기능 구매 서비스 제공

## Team & Roles
### Team Lead
- crab (Hyunjae Chung) : Coordinator, Contracts(Sui Move), backend
### Members
- paori (Yongwon Seo) : Frontend, UX Design,
- Jaewon (Jaewon Kim) : Backend, DB, Wallet(zkLogin)
- Noru (Juhwan Park) : Frontend
- Seungjun (Seungjun Oh) : PM, Documenation, PR

## License & Dependency
GNU General Public License v3.0
