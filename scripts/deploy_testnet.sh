#!/bin/bash

# SuiWorld Testnet Deployment Script

echo "=========================================="
echo "SuiWorld Testnet Deployment"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK="testnet"
RPC_URL="https://fullnode.testnet.sui.io:443"
FAUCET_URL="https://faucet.testnet.sui.io"

# Check if sui is installed
if ! command -v sui &> /dev/null
then
    echo -e "${RED}Sui CLI is not installed. Please install it first.${NC}"
    echo "Installation guide: https://docs.sui.io/guides/developer/getting-started/sui-install"
    exit 1
fi

# Function to setup testnet environment
setup_testnet_env() {
    echo -e "${YELLOW}Setting up Testnet environment...${NC}"

    # Check if testnet environment exists
    if ! sui client envs | grep -q "testnet"; then
        echo "Creating testnet environment..."
        sui client new-env --alias testnet --rpc $RPC_URL
    fi

    # Switch to testnet
    echo "Switching to testnet..."
    sui client switch --env testnet

    echo -e "${GREEN}Testnet environment configured${NC}"
}

# Function to check wallet balance
check_balance() {
    echo -e "${YELLOW}Checking wallet balance...${NC}"

    local address=$(sui client active-address)
    echo "Active address: $address"

    # Get balance
    local balance=$(sui client balance | grep SUI | awk '{print $2}')
    echo "Current balance: $balance SUI"

    # Check if balance is sufficient (at least 1 SUI for deployment)
    if [[ -z "$balance" ]] || (( $(echo "$balance < 1" | bc -l) )); then
        echo -e "${YELLOW}Insufficient balance. Requesting test tokens...${NC}"
        request_test_tokens
    else
        echo -e "${GREEN}Balance is sufficient for deployment${NC}"
    fi
}

# Function to request test tokens
request_test_tokens() {
    echo -e "${YELLOW}Requesting test SUI tokens...${NC}"

    local address=$(sui client active-address)

    # Try using the CLI faucet first
    if ! sui client faucet; then
        echo "CLI faucet failed. Trying web faucet..."

        # Alternative: Use curl to request from web faucet
        local response=$(curl -s -X POST $FAUCET_URL/v1/gas \
            -H "Content-Type: application/json" \
            -d "{\"wallet_address\": \"$address\"}")

        if [[ $response == *"error"* ]]; then
            echo -e "${RED}Failed to get test tokens. Please try:${NC}"
            echo "1. Visit https://faucet.testnet.sui.io"
            echo "2. Connect your wallet"
            echo "3. Request test SUI"
            echo "Your address: $address"
            exit 1
        fi
    fi

    echo "Waiting for tokens to arrive..."
    sleep 5

    # Verify tokens received
    local new_balance=$(sui client balance | grep SUI | awk '{print $2}')
    echo -e "${GREEN}New balance: $new_balance SUI${NC}"
}

# Function to update Move.toml for testnet
update_move_toml() {
    echo -e "${YELLOW}Updating Move.toml for testnet...${NC}"

    cd move

    # Backup current Move.toml
    cp Move.toml Move.toml.backup

    # Update for testnet
    cat > Move.toml << 'EOF'
[package]
name = "suiworld"
version = "0.0.1"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "testnet" }

[addresses]
suiworld = "0x0"

[sui]
flavor = "sui"
EOF

    echo -e "${GREEN}Move.toml updated for testnet${NC}"
    cd ..
}

# Function to build the package
build_package() {
    echo -e "${YELLOW}Building SuiWorld package...${NC}"

    cd move

    # Clean previous builds
    rm -rf build/

    if sui move build --skip-fetch-latest-git-deps; then
        echo -e "${GREEN}Package built successfully${NC}"
        cd ..
        return 0
    else
        echo -e "${RED}Build failed. Please check the errors above.${NC}"
        cd ..
        return 1
    fi
}

# Function to deploy the package
deploy_package() {
    echo -e "${YELLOW}Deploying SuiWorld package to testnet...${NC}"

    cd move

    # Deploy with high gas budget
    echo "Deploying with gas budget: 500000000 MIST"

    DEPLOY_OUTPUT=$(sui client publish --gas-budget 500000000 --skip-dependency-verification 2>&1)

    if echo "$DEPLOY_OUTPUT" | grep -q "Successfully"; then
        echo -e "${GREEN}Package deployed successfully!${NC}"

        # Extract package ID
        PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | grep -oE "PackageID: 0x[a-f0-9]{64}" | cut -d' ' -f2)

        if [ -z "$PACKAGE_ID" ]; then
            # Try alternative pattern
            PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | grep -oE "0x[a-f0-9]{64}" | head -1)
        fi

        if [ ! -z "$PACKAGE_ID" ]; then
            echo -e "${BLUE}Package ID: $PACKAGE_ID${NC}"

            # Save deployment info
            cd ..
            echo "NETWORK=$NETWORK" > .env.testnet
            echo "PACKAGE_ID=$PACKAGE_ID" >> .env.testnet
            echo "DEPLOYER=$(sui client active-address)" >> .env.testnet
            echo "RPC_URL=$RPC_URL" >> .env.testnet
            echo "DEPLOY_TIME=$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> .env.testnet
            echo "DEPLOY_TX=$(echo "$DEPLOY_OUTPUT" | grep -oE "Transaction digest: 0x[a-f0-9]+" | cut -d' ' -f3)" >> .env.testnet

            # Save package ID separately for easy access
            echo "$PACKAGE_ID" > deployed_package_testnet.txt

            # Save full deployment output for reference
            echo "$DEPLOY_OUTPUT" > deployment_testnet.log

            echo -e "${GREEN}Deployment info saved to:${NC}"
            echo "  - .env.testnet (environment variables)"
            echo "  - deployed_package_testnet.txt (package ID)"
            echo "  - deployment_testnet.log (full output)"

            # Extract and save important object IDs
            echo -e "${YELLOW}Extracting created objects...${NC}"
            echo "" >> .env.testnet
            echo "# Created Objects" >> .env.testnet

            # Parse created objects from deployment output
            if echo "$DEPLOY_OUTPUT" | grep -q "Created Objects:"; then
                echo "$DEPLOY_OUTPUT" | sed -n '/Created Objects:/,/^$/p' >> deployment_objects.txt
                echo -e "${GREEN}Object IDs saved to deployment_objects.txt${NC}"
            fi

            return 0
        else
            echo -e "${RED}Could not extract Package ID${NC}"
            echo "$DEPLOY_OUTPUT" > deployment_error.log
            return 1
        fi
    else
        echo -e "${RED}Deployment failed${NC}"
        echo "$DEPLOY_OUTPUT" > deployment_error.log
        echo "Check deployment_error.log for details"
        cd ..
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    echo -e "${YELLOW}Verifying deployment...${NC}"

    if [ ! -f "deployed_package_testnet.txt" ]; then
        echo -e "${RED}Package ID file not found${NC}"
        return 1
    fi

    PACKAGE_ID=$(cat deployed_package_testnet.txt)

    echo "Fetching package info..."
    sui client object $PACKAGE_ID

    echo -e "${GREEN}Deployment verified${NC}"
}

# Function to display next steps
show_next_steps() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Deployment Completed Successfully!${NC}"
    echo "=========================================="
    echo ""

    if [ -f "deployed_package_testnet.txt" ]; then
        PACKAGE_ID=$(cat deployed_package_testnet.txt)
        echo -e "${BLUE}Package ID:${NC} $PACKAGE_ID"
    fi

    echo -e "${BLUE}Network:${NC} Testnet"
    echo -e "${BLUE}RPC URL:${NC} $RPC_URL"
    echo -e "${BLUE}Explorer:${NC} https://testnet.suivision.xyz/package/$PACKAGE_ID"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Save your Package ID: $PACKAGE_ID"
    echo "2. View on explorer: https://testnet.suivision.xyz/package/$PACKAGE_ID"
    echo "3. Initialize contracts: ./scripts/initialize_testnet.sh"
    echo "4. Update frontend configuration with the Package ID"
    echo ""
    echo -e "${YELLOW}Interact with deployed contracts:${NC}"
    echo "sui client call --package $PACKAGE_ID --module <module> --function <function>"
    echo ""
    echo -e "${YELLOW}Important files created:${NC}"
    echo "  - .env.testnet: Environment configuration"
    echo "  - deployed_package_testnet.txt: Package ID"
    echo "  - deployment_testnet.log: Full deployment output"
    echo "  - deployment_objects.txt: Created object IDs"
}

# Main deployment flow
main() {
    echo "Starting testnet deployment process..."
    echo ""

    # Step 1: Setup testnet environment
    setup_testnet_env

    # Step 2: Check balance
    check_balance

    # Step 3: Update Move.toml
    # update_move_toml

    # Step 4: Build package
    if ! build_package; then
        echo -e "${RED}Build failed. Please fix errors and try again.${NC}"
        exit 1
    fi

    # Step 5: Deploy package
    if ! deploy_package; then
        echo -e "${RED}Deployment failed. Check deployment_error.log for details.${NC}"
        exit 1
    fi

    # Step 6: Verify deployment
    verify_deployment

    # Step 7: Show next steps
    show_next_steps
}

# Run main function
main
