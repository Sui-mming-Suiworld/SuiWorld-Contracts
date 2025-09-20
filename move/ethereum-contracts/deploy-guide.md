# Sepolia 배포 및 NTT 크로스체인 설정 가이드

## 1. Private Key 설정

### 방법 1: .env 파일 사용 (권장)
```bash
cd move/ethereum-contracts

# .env 파일 생성
cp .env.example .env

# .env 파일 편집
nano .env  # 또는 vim, code 등 사용
```

`.env` 파일 내용:
```bash
# Sepolia RPC (무료 옵션들)
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
# 또는
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
# 또는 공개 RPC (API 키 불필요)
SEPOLIA_RPC_URL=https://rpc.sepolia.org

# Private Key (0x 없이 입력)
PRIVATE_KEY=abc123def456...  # 0x 제외하고 입력
```

### 방법 2: 명령어에서 직접 입력
```bash
# 환경변수로 설정
export PRIVATE_KEY=your_private_key_without_0x
export SEPOLIA_RPC_URL=https://rpc.sepolia.org

# 배포
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## 2. Sepolia ETH 얻기 (가스비용)

### Sepolia Faucet 목록:
1. **Alchemy Faucet** (가장 안정적)
   - https://sepoliafaucet.com
   - 하루 0.5 ETH

2. **Infura Faucet**
   - https://www.infura.io/faucet/sepolia
   - 하루 0.5 ETH

3. **Chainlink Faucet**
   - https://faucets.chain.link/sepolia
   - 하루 0.1 ETH

## 3. 토큰 배포

```bash
cd move/ethereum-contracts

# 1. 의존성 설치 (처음 한번만)
forge install

# 2. 컴파일
forge build

# 3. 테스트 (선택사항)
forge test

# 4. Sepolia에 배포
make deploy-sepolia

# 또는 직접 명령어
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

배포 후 출력 예시:
```
SuiWorldToken deployed at: 0x1234567890abcdef...
```

**이 주소를 꼭 저장하세요!**

## 4. NTT CLI로 크로스체인 설정

### NTT CLI 설치
```bash
# NTT CLI 설치
npm install -g @wormhole-foundation/wormhole-ntt-cli

# 설치 확인
ntt --version
```

### NTT 프로젝트 초기화
```bash
# 프로젝트 디렉토리 생성
mkdir ~/suiworld-ntt
cd ~/suiworld-ntt

# NTT 프로젝트 생성
ntt new suiworld-bridge
cd suiworld-bridge

# Testnet으로 초기화
ntt init Testnet
```

### 체인 추가 및 설정

#### 1. Ethereum Sepolia 추가
```bash
# Ethereum Private Key 설정
export ETH_PRIVATE_KEY=your_ethereum_private_key

# Sepolia 체인 추가 (hub-and-spoke 모드)
ntt add-chain Sepolia --latest --mode locking \
  --token 0xYOUR_DEPLOYED_TOKEN_ADDRESS \
  --rpc https://rpc.sepolia.org

# 또는 burn-and-mint 모드
ntt add-chain Sepolia --latest --mode burning \
  --token 0xYOUR_DEPLOYED_TOKEN_ADDRESS \
  --rpc https://rpc.sepolia.org
```

#### 2. Sui Testnet 추가
```bash
# Sui Private Key 내보내기
sui keytool export --key-identity your-key-alias
export SUI_PRIVATE_KEY=your_sui_private_key

# Sui 체인 추가 (burn-and-mint 모드)
ntt add-chain Sui --latest --mode burning \
  --token 0xYOUR_PACKAGE::token::TOKEN \
  --sui-treasury-cap YOUR_TREASURY_CAP_ID

# 또는 hub-and-spoke 모드 (Sui가 spoke인 경우)
ntt add-chain Sui --latest --mode locking \
  --token 0xYOUR_PACKAGE::token::TOKEN
```

### Rate Limits 설정
`deployment.json` 편집:
```json
{
  "chains": {
    "Sepolia": {
      "inbound": {
        "Sui": "10000.000000"  // Sui -> Sepolia 한도
      },
      "outbound": {
        "Sui": "10000.000000"  // Sepolia -> Sui 한도
      }
    },
    "Sui": {
      "inbound": {
        "Sepolia": "10000.000000"  // Sepolia -> Sui 한도
      },
      "outbound": {
        "Sepolia": "10000.000000"  // Sui -> Sepolia 한도
      }
    }
  }
}
```

### 설정 적용
```bash
# 설정을 온체인에 적용
ntt push

# 상태 확인
ntt status
```

## 5. 토큰 전송 테스트

### Sepolia → Sui 전송
```bash
ntt transfer \
  --from Sepolia \
  --to Sui \
  --amount 100.0 \
  --recipient 0xYOUR_SUI_ADDRESS
```

### Sui → Sepolia 전송
```bash
ntt transfer \
  --from Sui \
  --to Sepolia \
  --amount 100.0 \
  --recipient 0xYOUR_ETHEREUM_ADDRESS
```

### 전송 모니터링
```bash
# 전송 상태 확인
ntt status

# 특정 트랜잭션 추적
ntt monitor --tx YOUR_TX_HASH

# Wormhole Explorer에서 확인
# https://wormholescan.io/#/
```

## 6. NTT Manager 주소 업데이트

NTT 배포 후 Ethereum 토큰에 NTT Manager 설정:

```bash
# .env 파일 업데이트
echo "TOKEN_ADDRESS=0xYOUR_TOKEN_ADDRESS" >> .env
echo "NTT_MANAGER_ADDRESS=0xNTT_MANAGER_ADDRESS" >> .env

# NTT Manager 설정
make setup-ntt
```

## 문제 해결

### 1. "Insufficient funds" 에러
- Sepolia ETH가 충분한지 확인
- Faucet에서 더 받기

### 2. "Rate limit exceeded" 에러
- deployment.json의 rate limit 증가
- `ntt push`로 재적용

### 3. "Peer not set" 에러
- 양쪽 체인이 모두 설정되었는지 확인
- `ntt status`로 상태 체크

### 4. Private Key 관련 에러
- 0x 접두사 제거했는지 확인
- 올바른 형식인지 확인 (64자 hex)

## 중요 주소들 (Testnet)

### Wormhole Chain IDs
- Ethereum Sepolia: 10002
- Sui Testnet: 21

### RPC Endpoints
- Sepolia: https://rpc.sepolia.org
- Sui Testnet: https://fullnode.testnet.sui.io

### Explorer
- Sepolia: https://sepolia.etherscan.io
- Sui: https://testnet.suivision.xyz
- Wormhole: https://wormholescan.io

## 보안 주의사항

1. **절대 Private Key를 공개하지 마세요**
2. `.env` 파일을 git에 커밋하지 마세요
3. 테스트넷에서 충분히 테스트 후 메인넷 진행
4. Rate limits를 적절히 설정하여 남용 방지