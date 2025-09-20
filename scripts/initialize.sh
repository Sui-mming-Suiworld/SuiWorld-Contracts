#!/bin/bash

# SuiWorld Testnet Initialization Script
# This script initializes the deployed contracts on testnet

echo "======================================"
echo "SuiWorld Testnet Initialization"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check dependencies
check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"

    # Check sui client
    if ! command -v sui &> /dev/null; then
        echo -e "${RED}Error: sui client not found${NC}"
        echo "Install with: brew install sui"
        exit 1
    fi

    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq not found${NC}"
        echo "Install with: brew install jq"
        exit 1
    fi

    echo -e "${GREEN}✓ All dependencies installed${NC}"
}

# Check network configuration
check_network() {
    echo -e "${BLUE}Checking network configuration...${NC}"

    CURRENT_ENV=$(sui client active-env)
    if [[ "$CURRENT_ENV" != *"testnet"* ]]; then
        echo -e "${YELLOW}Warning: Not on testnet. Current: $CURRENT_ENV${NC}"
        echo -e "${YELLOW}Switching to testnet...${NC}"
        sui client switch --env testnet
    fi

    CURRENT_ADDR=$(sui client active-address)
    echo -e "${GREEN}Active address: $CURRENT_ADDR${NC}"

    # Check gas balance
    echo -e "${BLUE}Checking gas balance...${NC}"
    GAS_OBJECTS=$(sui client gas --json)
    if [ "$(echo $GAS_OBJECTS | jq '. | length')" -eq 0 ]; then
        echo -e "${YELLOW}No gas coins found. Getting from faucet...${NC}"
        sui client faucet
        sleep 5
    fi
}

# Check if environment file exists
load_environment() {
    if [ -f ".env.testnet" ]; then
        source .env.testnet
        echo -e "${GREEN}Loaded testnet configuration${NC}"
        echo "Package ID: $PACKAGE_ID"
    else
        echo -e "${RED}Error: .env.testnet not found${NC}"
        echo -e "${RED}Please run deployment first:${NC}"
        echo "  sui client publish --gas-budget 200000000"
        echo "  Then save Package ID to .env.testnet"
        exit 1
    fi
}

# Run checks
check_dependencies
check_network
load_environment

# Initial manager addresses for testnet
# You can get test addresses using: sui client new-address ed25519
echo -e "${BLUE}=== Manager Configuration ===${NC}"
echo "Setting up initial managers..."

# For testnet, we'll use the deployer as the first manager by default
DEPLOYER_ADDR=$(sui client active-address)

INITIAL_MANAGERS=(
    # Manager 1: Deployer (automatic)
    "$DEPLOYER_ADDR"

    # Manager 2-12: Add your test addresses here
    # Generate new addresses with: sui client new-address ed25519
    # Example format: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"

    # Uncomment and replace with actual addresses:
    # "0xYOUR_TEST_MANAGER_2_ADDRESS"
    # "0xYOUR_TEST_MANAGER_3_ADDRESS"
    # "0xYOUR_TEST_MANAGER_4_ADDRESS"
    # "0xYOUR_TEST_MANAGER_5_ADDRESS"
    # "0xYOUR_TEST_MANAGER_6_ADDRESS"
    # "0xYOUR_TEST_MANAGER_7_ADDRESS"
    # "0xYOUR_TEST_MANAGER_8_ADDRESS"
    # "0xYOUR_TEST_MANAGER_9_ADDRESS"
    # "0xYOUR_TEST_MANAGER_10_ADDRESS"
    # "0xYOUR_TEST_MANAGER_11_ADDRESS"
    # "0xYOUR_TEST_MANAGER_12_ADDRESS"
)

echo "Configured ${#INITIAL_MANAGERS[@]} manager(s)"

# Function to get object IDs
get_object_ids() {
    echo -e "${BLUE}=== Finding Deployed Objects ===${NC}"
    echo "Scanning blockchain for SuiWorld objects..."

    # Get all objects owned by the deployer
    OBJECTS=$(sui client objects --json 2>/dev/null)

    if [ -z "$OBJECTS" ]; then
        echo -e "${RED}Error: Could not fetch objects${NC}"
        exit 1
    fi

    # More specific pattern matching for testnet
    # Package ID should be in the type string
    TREASURY_ID=$(echo $OBJECTS | jq -r --arg pkg "$PACKAGE_ID" '.[] | select(.type | contains($pkg) and contains("Treasury")) | .objectId' | head -n 1)
    REGISTRY_ID=$(echo $OBJECTS | jq -r --arg pkg "$PACKAGE_ID" '.[] | select(.type | contains($pkg) and contains("ManagerRegistry")) | .objectId' | head -n 1)
    BOARD_ID=$(echo $OBJECTS | jq -r --arg pkg "$PACKAGE_ID" '.[] | select(.type | contains($pkg) and contains("MessageBoard")) | .objectId' | head -n 1)
    VOTING_SYSTEM_ID=$(echo $OBJECTS | jq -r --arg pkg "$PACKAGE_ID" '.[] | select(.type | contains($pkg) and contains("VotingSystem")) | .objectId' | head -n 1)
    REWARD_SYSTEM_ID=$(echo $OBJECTS | jq -r --arg pkg "$PACKAGE_ID" '.[] | select(.type | contains($pkg) and contains("RewardSystem")) | .objectId' | head -n 1)
    SLASHING_SYSTEM_ID=$(echo $OBJECTS | jq -r --arg pkg "$PACKAGE_ID" '.[] | select(.type | contains($pkg) and contains("SlashingSystem")) | .objectId' | head -n 1)

    # Alternative method if objects not found (they might be shared objects)
    if [ -z "$TREASURY_ID" ]; then
        echo -e "${YELLOW}Searching in transaction history...${NC}"
        # Get recent transactions and look for created objects
        RECENT_TX=$(sui client query-transactions --limit 10 --json)
        # Parse for created shared objects (this is a simplified version)
    fi

    # Check if core objects are found
    if [ -z "$TREASURY_ID" ] || [ -z "$REGISTRY_ID" ] || [ -z "$BOARD_ID" ]; then
        echo -e "${RED}Error: Could not find all required objects${NC}"
        echo -e "${YELLOW}Found objects:${NC}"
        echo "  Treasury: ${TREASURY_ID:-NOT FOUND}"
        echo "  Registry: ${REGISTRY_ID:-NOT FOUND}"
        echo "  Board: ${BOARD_ID:-NOT FOUND}"
        echo ""
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo "1. Ensure deployment was successful"
        echo "2. Check Package ID is correct: $PACKAGE_ID"
        echo "3. Try running: sui client object $PACKAGE_ID"
        exit 1
    fi

    echo -e "${GREEN}✓ Found core objects:${NC}"
    echo "  Treasury: $TREASURY_ID"
    echo "  Registry: $REGISTRY_ID"
    echo "  Board: $BOARD_ID"

    if [ ! -z "$VOTING_SYSTEM_ID" ]; then
        echo "  VotingSystem: $VOTING_SYSTEM_ID"
    fi
    if [ ! -z "$REWARD_SYSTEM_ID" ]; then
        echo "  RewardSystem: $REWARD_SYSTEM_ID"
    fi
    if [ ! -z "$SLASHING_SYSTEM_ID" ]; then
        echo "  SlashingSystem: $SLASHING_SYSTEM_ID"
    fi

    # Save object IDs to file for future use
    cat > .env.testnet.objects << EOF
# SuiWorld Testnet Object IDs
# Generated: $(date)
export TREASURY_ID=$TREASURY_ID
export REGISTRY_ID=$REGISTRY_ID
export BOARD_ID=$BOARD_ID
export VOTING_SYSTEM_ID=$VOTING_SYSTEM_ID
export REWARD_SYSTEM_ID=$REWARD_SYSTEM_ID
export SLASHING_SYSTEM_ID=$SLASHING_SYSTEM_ID
EOF
    echo -e "${GREEN}✓ Saved object IDs to .env.testnet.objects${NC}"
}

# Function to mint initial manager NFTs
mint_manager_nfts() {
    echo -e "${BLUE}=== Minting Manager NFTs ===${NC}"

    # Get Registry ID if not already set
    if [ -z "$REGISTRY_ID" ]; then
        echo -e "${RED}Registry ID not found${NC}"
        return 1
    fi

    local success_count=0
    local fail_count=0
    local skipped_count=0

    # Process each manager
    for i in "${!INITIAL_MANAGERS[@]}"; do
        MANAGER_ADDR=${INITIAL_MANAGERS[$i]}
        MANAGER_NUM=$((i+1))

        # Skip if no address
        if [ -z "$MANAGER_ADDR" ]; then
            ((skipped_count++))
            continue
        fi

        echo -e "${BLUE}Manager #$MANAGER_NUM${NC}"
        echo "  Address: ${MANAGER_ADDR:0:16}...${MANAGER_ADDR: -6}"
        echo -n "  Minting NFT... "

        # Execute the minting transaction
        TX_RESULT=$(sui client call \
            --package $PACKAGE_ID \
            --module manager_nft \
            --function mint_manager_nft \
            --args $REGISTRY_ID $MANAGER_ADDR "\"Manager #$MANAGER_NUM\"" "\"SuiWorld Testnet Manager\"" \
            --gas-budget 10000000 \
            --json 2>&1)

        if [ $? -eq 0 ]; then
            # Extract transaction digest
            TX_DIGEST=$(echo $TX_RESULT | jq -r '.digest' 2>/dev/null)
            if [ ! -z "$TX_DIGEST" ]; then
                echo -e "${GREEN}✓${NC}"
                echo "  TX: ${TX_DIGEST:0:16}..."
                ((success_count++))
            else
                echo -e "${RED}✗${NC}"
                echo "  Error: Could not parse transaction result"
                ((fail_count++))
            fi
        else
            echo -e "${RED}✗${NC}"

            # Check for specific errors
            if [[ "$TX_RESULT" == *"MAX_MANAGERS_REACHED"* ]]; then
                echo "  Error: Maximum managers (12) already reached"
            elif [[ "$TX_RESULT" == *"InsufficientGas"* ]]; then
                echo "  Error: Insufficient gas. Run: sui client faucet"
            else
                echo "  Error: Transaction failed"
            fi
            ((fail_count++))
        fi

        # Delay between transactions
        if [ $i -lt $((${#INITIAL_MANAGERS[@]} - 1)) ]; then
            sleep 2
        fi
    done

    # Summary
    echo ""
    echo -e "${BLUE}=== NFT Minting Summary ===${NC}"
    echo -e "  ${GREEN}Success: $success_count${NC}"
    echo -e "  ${RED}Failed: $fail_count${NC}"
    echo -e "  ${YELLOW}Skipped: $skipped_count${NC}"

    if [ $success_count -gt 0 ]; then
        echo -e "${GREEN}✓ Manager NFTs minted successfully${NC}"
    else
        echo -e "${YELLOW}⚠ No NFTs were minted${NC}"
    fi
}

# Function to setup initial SWT distribution
distribute_initial_tokens() {
    echo -e "${BLUE}=== Initial Token Distribution ===${NC}"

    if [ -z "$TREASURY_ID" ]; then
        echo -e "${RED}Treasury ID not found${NC}"
        return 1
    fi

    echo "Distributing test tokens from Treasury..."

    # Transfer some SWT to deployer for testing
    echo -n "Transferring 10,000 SWT to deployer... "

    TX_RESULT=$(sui client call \
        --package $PACKAGE_ID \
        --module token \
        --function transfer_from_treasury \
        --args $TREASURY_ID 10000000000 $(sui client active-address) \
        --gas-budget 10000000 \
        --json 2>&1)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        TX_DIGEST=$(echo $TX_RESULT | jq -r '.digest' 2>/dev/null)
        echo "  TX: ${TX_DIGEST:0:16}..."
    else
        echo -e "${RED}✗${NC}"
        echo "  Could not transfer tokens"
    fi
}

# Function to display contract info and instructions
display_contract_info() {
    echo ""
    echo -e "${BLUE}======================================"
    echo "   SuiWorld Testnet Deployment Info"
    echo "======================================${NC}"

    echo -e "${GREEN}Network:${NC} Sui Testnet"
    echo -e "${GREEN}Package ID:${NC} $PACKAGE_ID"
    echo ""

    echo -e "${YELLOW}Core Object IDs:${NC}"
    echo "  Treasury:       $TREASURY_ID"
    echo "  Registry:       $REGISTRY_ID"
    echo "  MessageBoard:   $BOARD_ID"

    if [ ! -z "$VOTING_SYSTEM_ID" ]; then
        echo "  VotingSystem:   $VOTING_SYSTEM_ID"
    fi
    if [ ! -z "$REWARD_SYSTEM_ID" ]; then
        echo "  RewardSystem:   $REWARD_SYSTEM_ID"
    fi
    if [ ! -z "$SLASHING_SYSTEM_ID" ]; then
        echo "  SlashingSystem: $SLASHING_SYSTEM_ID"
    fi

    echo ""
    echo -e "${YELLOW}Testnet Explorer:${NC}"
    echo "  https://suiexplorer.com/object/$PACKAGE_ID?network=testnet"

    echo ""
    echo -e "${YELLOW}Example Commands:${NC}"
    echo ""
    echo "# Check Treasury balance:"
    echo "sui client object $TREASURY_ID"
    echo ""
    echo "# Transfer SWT from Treasury:"
    echo "sui client call \\"
    echo "  --package $PACKAGE_ID \\"
    echo "  --module token \\"
    echo "  --function transfer_from_treasury \\"
    echo "  --args $TREASURY_ID <amount> <recipient> \\"
    echo "  --gas-budget 10000000"
    echo ""
    echo "# Create a message (needs SWT):"
    echo "sui client call \\"
    echo "  --package $PACKAGE_ID \\"
    echo "  --module message \\"
    echo "  --function create_message \\"
    echo "  --args $BOARD_ID <swt_coin> <title_hash> <content_hash> '[]' \\"
    echo "  --gas-budget 10000000"
}

# Function to save deployment info
save_deployment_info() {
    echo ""
    echo -e "${BLUE}Saving deployment information...${NC}"

    # Create deployment summary file
    cat > deployment_summary_testnet.md << EOF
# SuiWorld Testnet Deployment Summary

**Date**: $(date)
**Network**: Sui Testnet
**Deployer**: $(sui client active-address)

## Package Information
- **Package ID**: \`$PACKAGE_ID\`
- **Explorer**: [View on Sui Explorer](https://suiexplorer.com/object/$PACKAGE_ID?network=testnet)

## Object IDs
| Object | ID |
|--------|-----|
| Treasury | \`$TREASURY_ID\` |
| ManagerRegistry | \`$REGISTRY_ID\` |
| MessageBoard | \`$BOARD_ID\` |
| VotingSystem | \`${VOTING_SYSTEM_ID:-N/A}\` |
| RewardSystem | \`${REWARD_SYSTEM_ID:-N/A}\` |
| SlashingSystem | \`${SLASHING_SYSTEM_ID:-N/A}\` |

## Managers
Total configured: ${#INITIAL_MANAGERS[@]}

## Next Steps
1. Fund Treasury for DEX listing
2. List SWT on Cetus/Turbos testnet
3. Setup backend API with object IDs
4. Configure frontend with testnet RPC

## Commands Reference
\`\`\`bash
# Get SWT from Treasury
sui client call --package $PACKAGE_ID --module token --function transfer_from_treasury --args $TREASURY_ID <amount> <address> --gas-budget 10000000

# Check objects
sui client objects
\`\`\`
EOF

    echo -e "${GREEN}✓ Saved to deployment_summary_testnet.md${NC}"
}

# Main initialization flow
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   SuiWorld Testnet Initialization     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Get object IDs
    get_object_ids

    echo ""

    # Step 2: Initialize manager NFTs
    mint_manager_nfts

    echo ""

    # Step 3: Distribute initial tokens
    distribute_initial_tokens

    # Step 4: Display deployment info
    display_contract_info

    # Step 5: Save deployment info
    save_deployment_info

    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}     ✓ Initialization Complete!         ${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Important Next Steps:${NC}"
    echo "1. Add more manager addresses to the INITIAL_MANAGERS array"
    echo "2. Transfer SWT to DEX wallet for liquidity provision"
    echo "3. List SWT on Cetus or Turbos testnet"
    echo "4. Update backend/frontend configs with object IDs"
    echo ""
    echo -e "${BLUE}Check deployment_summary_testnet.md for detailed info${NC}"
}

# Run main function
main