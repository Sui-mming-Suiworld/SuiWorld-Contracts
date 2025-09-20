# SuiWorld Local Deployment Guide

## Prerequisites

1. Install Sui CLI:
```bash
# macOS
brew install sui

# Or from source
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch mainnet sui
```

2. Verify installation:
```bash
sui --version
```

## Local Network Deployment

### Step 1: Start Local Network

```bash
# Start Sui local validator
sui-test-validator

# Keep this running in a separate terminal
```

### Step 2: Deploy Contracts

```bash
# Run the deployment script
./scripts/deploy_local.sh
```

This script will:
- Start local network (if not running)
- Configure client for localnet
- Request test SUI tokens
- Build the Move packages
- Deploy all contracts
- Save deployment info to `.env.local`

### Step 3: Initialize Contracts

After successful deployment, initialize the platform with initial data:

```bash
# Run initialization script
./scripts/initialize.sh
```

#### What the Initialization Script Does:

1. **Manager NFT Distribution**
   - Mints NFTs for 12 initial managers
   - Sets up governance participants
   - Grants voting and management privileges

2. **Liquidity Pool Setup**
   - Adds initial liquidity to SUI ↔ SWT swap pool
   - Sets starting exchange rate
   - Enables token trading functionality

3. **Test Content Creation**
   - Creates sample messages with hashed content
   - Stores original content off-chain
   - Demonstrates hash-based storage system
   - Provides initial content hashes for UI testing

4. **System Information Display**
   - Shows deployed Package ID
   - Lists available modules and functions
   - Provides interaction command examples

**Note**: The script requires `deployed_package_id.txt` file from deployment step. In production, you'll need to capture actual object IDs from the deployment transaction.

## Manual Deployment Steps

If you prefer to deploy manually:

### 1. Configure Local Network

```bash
# Add local network
sui client new-env --alias localnet --rpc http://127.0.0.1:9000

# Switch to local network
sui client switch --env localnet

# Get test tokens
sui client faucet
```

### 2. Build Contracts

```bash
cd move
sui move build
```

### 3. Deploy Contracts

```bash
# Deploy with high gas budget for complex contracts
sui client publish --gas-budget 100000000 --skip-dependency-verification
```

### 4. Save Package ID

Copy the Package ID from the deployment output and save it:
```bash
echo "PACKAGE_ID=<your_package_id>" > .env.local
```

## Interacting with Deployed Contracts

### Example: Mint Manager NFT

```bash
sui client call \
    --package <PACKAGE_ID> \
    --module manager_nft \
    --function mint_manager_nft \
    --args <REGISTRY_ID> <RECIPIENT> "Manager Name" "Description" \
    --gas-budget 10000000
```

### Example: Create Message

```bash
# First, generate hashes for your content (off-chain)
# Example using sha256:
# TITLE_HASH=$(echo -n "Your Title" | sha256sum | cut -d' ' -f1)
# CONTENT_HASH=$(echo -n "Your Content" | sha256sum | cut -d' ' -f1)

sui client call \
    --package <PACKAGE_ID> \
    --module message \
    --function create_message \
    --args <BOARD_ID> <SWT_COIN> 0x<TITLE_HASH> 0x<CONTENT_HASH> '["tag1","tag2"]' \
    --gas-budget 10000000
```

### Example: Transfer from Treasury

```bash
sui client call \
    --package <PACKAGE_ID> \
    --module token \
    --function transfer_from_treasury \
    --args <TREASURY_ID> <AMOUNT> <RECIPIENT> \
    --gas-budget 10000000
```

**Note**: SWT tokens can be traded on external DEXs like Cetus or Turbos after listing.

## Object IDs

After deployment, important object IDs will be created:
- Treasury (from token module)
- ManagerRegistry (from manager_nft module)
- MessageBoard (from message module)
- VotingSystem (from vote module)
- RewardSystem (from rewards module)
- SlashingSystem (from slashing module)

You can find these in the deployment transaction output.

## Troubleshooting

### Port 9000 Already in Use
```bash
# Find and kill the process
lsof -i :9000
kill -9 <PID>
```

### Build Errors
- Ensure you're using the latest Sui version
- Check that all dependencies are properly specified in Move.toml
- Verify that all module imports are correct

### Gas Errors
- Increase gas budget if deployment fails
- Default local network provides plenty of test SUI

## Testing

### Run Move Tests
```bash
cd move
sui move test
```

### Check Deployment
```bash
# View objects owned by your address
sui client objects

# View specific object
sui client object <OBJECT_ID>
```

## Next Steps

1. Connect the frontend to the deployed contracts
2. Update `.env` with the deployed package and object IDs
3. Test all contract functions
4. Monitor events using `sui client events`

## Contract Architecture

- **token.move**: SWT token with treasury and swap pool
- **manager_nft.move**: NFT system for platform managers
- **message.move**: Message creation and management (stores only hashes of content)
  - Title and content are stored as hashes (vector<u8>)
  - Original content should be stored off-chain (IPFS, Arweave, etc.)
  - Comments also store only content hashes
- **vote.move**: Voting system for content moderation
- **swap.move**: AMM for SUI <-> SWT swaps
- **rewards.move**: Reward distribution system
- **slashing.move**: Penalty system for violations

## Important Notes

- Local network data is ephemeral and will be lost when the validator stops
- For persistent testing, consider using devnet
- Always save important object IDs after deployment
- Test all critical paths before mainnet deployment