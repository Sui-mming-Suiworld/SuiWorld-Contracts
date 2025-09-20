#!/bin/bash

# SuiWorld Local Deployment Script

echo "======================================"
echo "SuiWorld Local Network Deployment"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if sui is installed
if ! command -v sui &> /dev/null
then
    echo -e "${RED}Sui CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Function to check if local network is running
check_local_network() {
    echo "Checking local network status..."
    if sui client active-env | grep -q "localnet"; then
        echo -e "${GREEN}Local network is configured${NC}"
        return 0
    else
        echo "Setting up local network..."
        sui client new-env --alias localnet --rpc http://127.0.0.1:9000
        return $?
    fi
}

# Function to start local network
start_local_network() {
    echo "Starting Sui local network..."

    # Check if local network is already running
    if lsof -Pi :9000 -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${GREEN}Local network is already running on port 9000${NC}"
    else
        echo "Starting new local network instance..."
        sui-test-validator &

        # Wait for the network to start
        echo "Waiting for local network to initialize..."
        sleep 5

        # Check if it started successfully
        if lsof -Pi :9000 -sTCP:LISTEN -t >/dev/null ; then
            echo -e "${GREEN}Local network started successfully${NC}"
        else
            echo -e "${RED}Failed to start local network${NC}"
            exit 1
        fi
    fi
}

# Function to get active address
get_active_address() {
    sui client active-address
}

# Function to request test tokens
request_test_tokens() {
    echo "Requesting test SUI tokens..."
    sui client faucet
    sleep 2
    echo -e "${GREEN}Test tokens received${NC}"
}

# Function to build the package
build_package() {
    echo "Building SuiWorld package..."
    cd move

    if sui move build; then
        echo -e "${GREEN}Package built successfully${NC}"
        return 0
    else
        echo -e "${RED}Build failed${NC}"
        return 1
    fi
}

# Function to deploy the package
deploy_package() {
    echo "Deploying SuiWorld package..."
    cd move

    # Deploy with skip-dependency-verification for local testing
    DEPLOY_OUTPUT=$(sui client publish --gas-budget 100000000 --skip-dependency-verification 2>&1)

    if echo "$DEPLOY_OUTPUT" | grep -q "Successfully"; then
        echo -e "${GREEN}Package deployed successfully${NC}"

        # Extract package ID
        PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | grep -oP 'PackageID: \K[^\s]+' | head -1)

        if [ -z "$PACKAGE_ID" ]; then
            # Try alternative pattern
            PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | grep -oP '0x[a-f0-9]{64}' | head -1)
        fi

        if [ ! -z "$PACKAGE_ID" ]; then
            echo "Package ID: $PACKAGE_ID"

            # Save package ID to file
            echo "$PACKAGE_ID" > ../deployed_package_id.txt
            echo -e "${GREEN}Package ID saved to deployed_package_id.txt${NC}"

            # Save deployment info
            echo "NETWORK=localnet" > ../.env.local
            echo "PACKAGE_ID=$PACKAGE_ID" >> ../.env.local
            echo "DEPLOYER=$(get_active_address)" >> ../.env.local
            echo "DEPLOY_TIME=$(date)" >> ../.env.local

            echo -e "${GREEN}Deployment info saved to .env.local${NC}"
        fi

        return 0
    else
        echo -e "${RED}Deployment failed${NC}"
        echo "$DEPLOY_OUTPUT"
        return 1
    fi
}

# Main deployment flow
main() {
    echo "Starting deployment process..."

    # Step 1: Check/start local network
    start_local_network

    # Step 2: Configure client for local network
    check_local_network

    # Step 3: Switch to localnet
    echo "Switching to local network..."
    sui client switch --env localnet

    # Step 4: Get test tokens
    request_test_tokens

    # Step 5: Build package
    if ! build_package; then
        echo -e "${RED}Build failed. Exiting...${NC}"
        exit 1
    fi

    # Step 6: Deploy package
    if ! deploy_package; then
        echo -e "${RED}Deployment failed. Exiting...${NC}"
        exit 1
    fi

    echo "======================================"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo "======================================"

    # Display deployment summary
    if [ -f deployed_package_id.txt ]; then
        echo "Package ID: $(cat deployed_package_id.txt)"
        echo "Active Address: $(get_active_address)"
        echo "Network: localnet (http://127.0.0.1:9000)"
    fi
}

# Run main function
main