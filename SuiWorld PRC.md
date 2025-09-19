# SuiWorld PRC

## Intro / Vision
이미 공유 다 함

## Function Goals

### Login / Token Transfer(Swap)
zklogin을 통한 Wallet 생성
Wallet - Profile 연동 (class에 Profile image link, ID, description element 필요)
SWT token Mint (100,000,000 SWT - 30% Team, 70% Pool)
Sui <> SWT Swap Pool

### Gallery
- 2개 갤러리 존재 (갤러리 생성, 매니저 지정은 미리 만들어두고 기능 구현 따로 X)
    - Degen Gallery (3 Degen Manager NFT 발행, 3명 매니저 지정)
    - Dev Gallery (3 Dev Manager NFT 발행, 3명 매니저 지정)

- 각 Gallery 별 message CRUD 기능
    - C : >1000 SWT
    - R : Free
    - U : >1000 SWT (ex. comment 등록, likes, alert 등), Who hold Manager NFT(Hyped)
    - D : Who hold Gallery Manager NFT

### Hype message interaction
- over 20 likes -> 3 Manager Vote about Hyped message upgrade ->over 2 agree, update
- if Hyped
    - +100SWT for creator (Team -> Creator)
    - +10SWT for Manager (Team -> Manager)

### scam message interaction
- over 20 alerts -> 3 Manager Vote about Hyped message upgrade ->over 2 agree, delete
- if deleted
    - -200SWT for creator (Creator -> Team)
    - +10SWT for Manager (Team -> Manager)

## MVP

- zklogin - Profile creation - minimum SUI<>SWT Swap - Write a message - interaction in platform(incentive/slashing)

- (if manager) Vote - update/delete message (incentive)
