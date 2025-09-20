# SuiWorld 프로젝트 아키텍처 & 용어 정리

이 문서는 SuiWorld 커뮤니티 앱의 최신 구조와 주요 개념을 정리합니다. 현재 서비스는 "갤러리" 구성을 폐기하고, 단일 Home 피드에서 메시지를 작성하고 공유하는 흐름으로 단순화되었습니다.

## 1. 전체 아키텍처

SuiWorld는 Sui 블록체인 위에서 동작하는 탈중앙 커뮤니티 애플리케이션입니다. 프론트엔드에서 사용자의 상호작용을 처리하고, 백엔드가 API와 Off-chain 데이터를 조율하며, 온체인 Move 모듈이 토큰/슬래싱 로직을 담당합니다.

```
[ User ]
    |
    v
[ Frontend (Next.js) ] <--> [ Backend (FastAPI) ] <--> [ Database (PostgreSQL)]
                                      |
                                      v
                        [ Sui Blockchain (Move Modules) ]
```

## 2. 디렉터리별 주요 구성

### `/frontend`
- **Next.js + TypeScript** 기반의 클라이언트 앱.
- `app/page.tsx`: 단일 Home 피드를 노출하는 진입점. 메시지 목록, 정렬/검색 필터, Swap 진입부를 배치할 예정입니다.
- `hooks/usecases/feed.usecase.ts`: Home 피드 메시지 조회/작성 로직을 묶기 위한 훅 스텁.
- `lib/`: 공통 fetcher, Sui provider 등의 헬퍼.
- `types/api.ts`: 백엔드와 주고받는 데이터 타입 정의.
- **이전 갤러리 전용 페이지(`app/gallery/[slug]`)는 삭제되었습니다.**

### `/backend`
- **FastAPI** 기반의 API 서버.
- `app/main.py`: FastAPI 앱 초기화 및 라우터 등록.
- `app/api/messages.py`: Home 피드 메시지를 반환하는 엔드포인트. 검색, 태그 필터, 정렬 옵션을 지원합니다.
- `app/services/messages.py`: 인메모리 시드 데이터와 상태 계산 로직. 갤러리 구분 없이 전체 피드를 구성합니다.
- `app/schemas.py`: 메시지/작성자/메트릭 응답 스키마.
- `app/api/galleries.py`: 구 갤러리 API. 현재는 410 GONE을 응답하도록 막아 두고 있습니다.
- `tests/test_messages_api.py`: Home 피드 API 커버리지.
- `tests/conftest.py`: 테스트에서 애플리케이션 패키지를 import 할 수 있도록 sys.path 설정.

### `/move`
- Sui Move 모듈이 위치한 영역.
- `sources/`: 토큰, 투표, 스왑 로직 등이 들어 있는 Move 소스. 과거 갤러리 관련 모듈(`gallery.move`)은 순차적으로 정리 예정입니다.
- `Move.toml`: Move 패키지 설정.

### `/scripts`
- 로컬 환경 설정 및 유틸리티 스크립트 (`devnet-init.sh`, `env.sample`, `seed.sql` 등).

## 3. 도메인 용어 & 흐름

- **메시지(Message)**: 사용자가 Home 피드에 게시하는 컨텐츠 단위. 텍스트 및 태그 정보를 포함합니다.
- **Home Feed**: 모든 메시지를 모아 보여주는 단일 타임라인. 갤러리 개념을 제거하고 글로벌 피드로 통일했습니다.
- **태그 필터링**: 메시지에 부착된 태그를 OR/AND 모드로 필터링.
- **정렬 옵션**: 최신 순(`latest`), 좋아요 순(`likes`), 경고 순(`alerts`), 검토 상태 우선(`under_review`)을 지원합니다.
- **상태(Status)**:
  - `NORMAL`: 기본 상태.
  - `UNDER_REVIEW`: 좋아요 또는 경고 20건 이상 누적 시 자동 전환.
  - `HYPED` / `SPAM` / `DELETED`: 매니저 투표 결과로 부여되는 조정 상태.
- **Manager**: Manager NFT를 보유한 검증자. 메시지에 대한 승격(Hype) 또는 제재(Spam/Deleted) 투표 권한을 가집니다.
- **Proposal**: 좋아요 20건 이상(Hype 후보) 또는 경고 20건 이상(Scam 후보)일 때 생성되는 투표 항목. 12명 매니저 중 4명 이상이 찬성/반대하면 확정됩니다.

## 4. SWT 토큰 사용 정책

- **작성/수정 자격**: 메시지를 새로 작성하거나 수정하려면 최소 1000 SWT 이상을 보유하고 있어야 합니다. *토큰이 소모되는 것은 아니며, 보유량을 기준으로 접근 권한을 제어합니다.*
- **보상 구조**:
  - 메시지가 Hype로 승격되면 작성자는 +100 SWT, 매니저는 +10 SWT 보상을 받습니다.
  - Scam으로 확정되면 작성자는 -200 SWT, 매니저는 +10 SWT가 부여됩니다.
- **슬래싱**: 반복적으로 오판을 하는 매니저는 Manager NFT가 슬래싱(소각)되고 차기 후보에게 위임됩니다.

## 5. 앞으로의 정비 항목

- 백엔드 인메모리 시드를 실제 DB/체인 데이터로 교체.
- 프론트엔드 Home 피드 UI 구현 및 정렬/필터 연동.
- Move 모듈에서 갤러리 관련 잔여 코드를 제거하고 Feed 중심 로직으로 재구성.
- Pydantic v2 스타일까지 마이그레이션하여 경고 제거.

이 문서는 구조 변화가 있을 때마다 갱신하여 팀 내 공통 용어와 아키텍처 이해를 유지하는 용도로 활용합니다.
