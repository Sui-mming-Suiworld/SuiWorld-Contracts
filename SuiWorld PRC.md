# SuiWorld PRC

## Intro / Vision
Kaito 를 기점으로 성행하는 InfoFi - 이른바 "Yapping"메타는 크립토 메신저 트랜잭션에 큰 성장을 가져왔지만, 역으로 meaningless한 트윗들이 남발하게 되어 양질의 정보를 얻기 어려운 현상을 만들었다.
양질의 정보를 얻을 수 있는 커뮤니티를 만들고 싶다. 이를 위해 커뮤니티에 incentive tokenomics를 제시한다. 양질의 글을 쓰는 자들, 커뮤니티를 자발적으로 관리하는 자들에게 incentive를, 스캠과 같은 meaningless한 글을 쓰는 경우 disadvantage를 제공한다. multichain product들을 위해 Wormhole NTT를 통한 Native Token <> SWT swap을 제공하고, Native token들의 경우 Cooking Message 작성자들에게 정기적으로 randomly하게 Airdrop하여 양질의 글을 지속적으로 쓰게 할 원동력을 제공한다.

## parameter selection

- User : 500 가정
- Manager : 12명
- Hype 기준 : 20 likes > Managers' vote
- scam 기준 : 20 alerts > Managers' vote

## Function Goals

### Login / Token Transfer(Swap)
zklogin을 통한 Wallet 생성
Wallet - Profile 연동 (class에 Profile image link, ID, description element 필요)
SWT token Mint (100,000,000 SWT - 30% Treasury, 70% Pool)
Sui <> SWT Swap Pool

### Home
- Messanger가 보이는 메인 화면
- Manager Candidate List 구성 (List : Sui Validator, Influencer, friendly Research Firm etc). in initial : list[0:12]에게 제공. 이 NFT는 trade 가능 (not Soulbound).이로 인한 부작용은 Manager misjudgment check func을 통해 해결.

- message CRUD 기능
    - C : >1000 SWT
    - R : Free
    - U : >1000 SWT (ex. comment 등록, likes, alert 등), Who hold Manager NFT(Hyped)
    - D : Who hold Manager NFT

### proposal func (this is for user's message)
there is two type of proposal, hyped and scam
#### Hype message interaction
- over 20 likes -> 12 Manager Vote about Hyped message upgrade -> over 4 agree, update() / over 4 disagree, reject (둘 중 하나라도 먼저 수행되는 경우 resolved)
- if Hyped
    - +100SWT for creator (Team -> Creator)
    - +10SWT for Manager (Team -> Manager)

#### scam message interaction
- over 20 alerts -> 12 Manager Vote about Hyped message upgrade -> over 4 agree, delete / over 4 disagree, reject
- if deleted
    - -200SWT for creator (Creator -> Team)
    - +10SWT for Manager (Team -> Manager)

### Manager_proposal func
 - manager can open manager_proposal with clicked report button in manager listed page. -> Each manager vote about deactivating manager who was reported -> over 8 agree, they slashed(burned) Manage NFT and Mint New Manager NFT for next expected Manager.

### Cooking
 - Hyped message를 확인할 수 있는 화면

## MVP

- zklogin - Profile creation - minimum SUI<>SWT Swap - Write a message - interaction in platform(incentive/slashing)
- (if manager) Vote - update/delete message (incentive)


## Sponsor Track Needed element

### NTT Swap
two chain link needed.
(ex. ETH, SOL)

- SuiWorld is for a Sui Ecosystem but nowadays there's so many multichain products.
- So we also can use a other native tokens for buy a SWT tokens. When they want to buy SWT, transfer Native token and Swap with SUI, and use SUI<>SWT Swap
- So, In Team's Treasury, there is some ETH, SOL now.
- in Weekly Period, for cooking message makers, randomly airdrop NTT Transfer tokens.

- needed function
    - NTT API Call
    - ETH<>SUI Swap
    - SOL<>SUI Swap
    - Token Airdrop
