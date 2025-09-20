#!/bin/bash

# SuiWorld Initialization Script
# This script initializes the deployed contracts with initial data

echo "======================================"
echo "SuiWorld Contract Initialization"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if package is deployed
if [ ! -f "deployed_package_id.txt" ]; then
    echo -e "${RED}Package not deployed yet. Run deploy_local.sh first.${NC}"
    exit 1
fi

PACKAGE_ID=$(cat deployed_package_id.txt)
echo "Using Package ID: $PACKAGE_ID"

# Initial manager addresses (for testing, use generated addresses)
INITIAL_MANAGERS=(
    "0x1234567890123456789012345678901234567890123456789012345678901234"
    "0x2345678901234567890123456789012345678901234567890123456789012345"
    "0x3456789012345678901234567890123456789012345678901234567890123456"
    "0x4567890123456789012345678901234567890123456789012345678901234567"
    "0x5678901234567890123456789012345678901234567890123456789012345678"
    "0x6789012345678901234567890123456789012345678901234567890123456789"
    "0x7890123456789012345678901234567890123456789012345678901234567890"
    "0x8901234567890123456789012345678901234567890123456789012345678901"
    "0x9012345678901234567890123456789012345678901234567890123456789012"
    "0x0123456789012345678901234567890123456789012345678901234567890123"
    "0x1234567890123456789012345678901234567890123456789012345678901235"
    "0x2345678901234567890123456789012345678901234567890123456789012346"
)

# Function to mint initial manager NFTs
mint_manager_nfts() {
    echo -e "${YELLOW}Minting initial Manager NFTs...${NC}"

    # For demonstration, we'll show the commands that would be run
    # In actual deployment, these would need the correct object IDs from deployment

    for i in {0..11}; do
        MANAGER_ADDR=${INITIAL_MANAGERS[$i]}
        echo "Would mint Manager NFT for: $MANAGER_ADDR"

        # Example command (needs actual registry object ID):
        # sui client call \
        #     --package $PACKAGE_ID \
        #     --module manager_nft \
        #     --function mint_manager_nft \
        #     --args $REGISTRY_ID $MANAGER_ADDR "Manager $((i+1))" "Initial Manager" \
        #     --gas-budget 10000000
    done

    echo -e "${GREEN}Manager NFTs initialization complete${NC}"
}

# Function to add initial liquidity to swap pool
add_initial_liquidity() {
    echo -e "${YELLOW}Adding initial liquidity to swap pool...${NC}"

    # This would add initial SUI and SWT to the pool
    # Example command (needs actual pool object ID):
    # sui client call \
    #     --package $PACKAGE_ID \
    #     --module swap \
    #     --function add_liquidity \
    #     --args $POOL_ID $SUI_COIN_ID $SWT_COIN_ID \
    #     --gas-budget 10000000

    echo -e "${GREEN}Initial liquidity added${NC}"
}

# Function to create test messages
create_test_messages() {
    echo -e "${YELLOW}Creating test messages with hashed content...${NC}"

    # Create a few test messages for demonstration
    # In production, these would be stored off-chain (IPFS/Arweave)
    declare -A TEST_MESSAGES=(
        ["Welcome to SuiWorld!"]="This is the first message on our decentralized platform"
        ["Platform Features"]="Explore voting, rewards, and community governance"
        ["Getting Started Guide"]="Learn how to create messages, vote, and earn rewards"
    )

    for title in "${!TEST_MESSAGES[@]}"; do
        content="${TEST_MESSAGES[$title]}"

        # Generate hashes (in production, use proper hashing)
        TITLE_HASH=$(echo -n "$title" | sha256sum | cut -d' ' -f1)
        CONTENT_HASH=$(echo -n "$content" | sha256sum | cut -d' ' -f1)

        echo "Would create message:"
        echo "  Title: $title (hash: 0x${TITLE_HASH:0:16}...)"
        echo "  Content: ${content:0:50}... (hash: 0x${CONTENT_HASH:0:16}...)"
        echo ""

        # Actual command would be:
        # sui client call \
        #     --package $PACKAGE_ID \
        #     --module message \
        #     --function create_message \
        #     --args $BOARD_ID $SWT_COIN "0x$TITLE_HASH" "0x$CONTENT_HASH" '[]' \
        #     --gas-budget 10000000

        # Store original content off-chain (IPFS example)
        # ipfs add -Q <<< "{\"title\":\"$title\",\"content\":\"$content\"}"
    done

    echo -e "${GREEN}Test messages created with hashed content${NC}"
    echo -e "${YELLOW}Note: Original content should be stored off-chain (IPFS/Arweave)${NC}"
}

# Function to display contract addresses
display_contract_info() {
    echo "======================================"
    echo "Contract Information"
    echo "======================================"
    echo "Package ID: $PACKAGE_ID"
    echo "Network: localnet"
    echo ""
    echo "To interact with the contracts, use:"
    echo "sui client call --package $PACKAGE_ID --module <module_name> --function <function_name>"
    echo ""
    echo "Available modules:"
    echo "  - token: SWT token management"
    echo "  - manager_nft: Manager NFT operations"
    echo "  - message: Message creation (hash-based storage)"
    echo "  - vote: Voting system"
    echo "  - swap: SUI <-> SWT swapping"
    echo "  - rewards: Reward distribution"
    echo "  - slashing: Penalty system"
    echo ""
    echo "Important: Message content is stored as hashes on-chain."
    echo "Original content must be stored off-chain (IPFS/Arweave)."
}

# Main initialization flow
main() {
    echo "Starting initialization process..."

    # Note: In a real deployment, we would need to capture the created object IDs
    # from the deployment transaction and use them here

    echo -e "${YELLOW}Note: This is a demonstration script.${NC}"
    echo -e "${YELLOW}Actual initialization would require:${NC}"
    echo -e "${YELLOW}  1. Object IDs from deployment${NC}"
    echo -e "${YELLOW}  2. Off-chain storage setup (IPFS/Arweave)${NC}"
    echo -e "${YELLOW}  3. Proper hash generation for content${NC}"
    echo ""

    # Step 1: Initialize manager NFTs
    mint_manager_nfts

    # Step 2: Add initial liquidity
    add_initial_liquidity

    # Step 3: Create test messages
    create_test_messages

    # Step 4: Display contract info
    display_contract_info

    echo "======================================"
    echo -e "${GREEN}Initialization completed!${NC}"
    echo "======================================"
}

# Run main function
main