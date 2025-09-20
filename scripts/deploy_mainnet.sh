#!/bin/bash

# SuiWorld Mainnet Deployment Script

echo "=========================================="
echo "SuiWorld Mainnet Deployment"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
NETWORK="mainnet"
RPC_URL="https://fullnode.mainnet.sui.io:443"

# Safety check
echo -e "${RED}╔════════════════════════════════════════╗${NC}"
echo -e "${RED}║         ⚠️  MAINNET DEPLOYMENT ⚠️         ║${NC}"
echo -e "${RED}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This script will deploy to MAINNET.${NC}"
echo -e "${YELLOW}Real SUI tokens will be used for gas.${NC}"
echo -e "${YELLOW}Deployments are permanent and irreversible.${NC}"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 0
fi

# Security checks
security_checks() {
    echo -e "${YELLOW}Performing security checks...${NC}"

    # Check if .env exists and warn about sensitive data
    if [ -f ".env" ]; then
        echo -e "${YELLOW}⚠️  Warning: .env file exists. Ensure no private keys are exposed.${NC}"
    fi

    # Check git status
    if git status --porcelain | grep -q .; then
        echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes.${NC}"
        echo "Consider committing changes before deployment."
        read -p "Continue anyway? (yes/no): " continue_anyway
        if [ "$continue_anyway" != "yes" ]; then
            echo -e "${RED}Deployment cancelled.${NC}"
            exit 0
        fi
    fi

    echo -e "${GREEN}Security checks completed.${NC}"
}

# Function to setup mainnet environment
setup_mainnet_env() {
    echo -e "${YELLOW}Setting up Mainnet environment...${NC}"

    # Check if mainnet environment exists
    if ! sui client envs | grep -q "mainnet"; then
        echo "Creating mainnet environment..."
        sui client new-env --alias mainnet --rpc $RPC_URL
    fi

    # Switch to mainnet
    echo "Switching to mainnet..."
    sui client switch --env mainnet

    echo -e "${GREEN}Mainnet environment configured${NC}"
}

# Function to check wallet balance
check_balance() {
    echo -e "${YELLOW}Checking wallet balance...${NC}"

    local address=$(sui client active-address)
    echo "Active address: $address"

    # Get balance
    local balance=$(sui client balance | grep SUI | awk '{print $2}')
    echo "Current balance: $balance SUI"

    # Check if balance is sufficient (at least 5 SUI recommended for mainnet)
    if [[ -z "$balance" ]] || (( $(echo "$balance < 5" | bc -l) )); then
        echo -e "${RED}Insufficient balance for mainnet deployment.${NC}"
        echo "Minimum recommended: 5 SUI"
        echo "Please fund your wallet at: $address"
        exit 1
    else
        echo -e "${GREEN}Balance is sufficient for deployment${NC}"
    fi
}

# Function to update Move.toml for mainnet
update_move_toml() {
    echo -e "${YELLOW}Updating Move.toml for mainnet...${NC}"

    cd move

    # Backup current Move.toml
    cp Move.toml Move.toml.backup

    # Update for mainnet
    cat > Move.toml << 'EOF'
[package]
name = "suiworld"
version = "1.0.0"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "mainnet" }

[addresses]
suiworld = "0x0"

[sui]
flavor = "sui"
EOF

    echo -e "${GREEN}Move.toml updated for mainnet${NC}"
    cd ..
}

# Function to run tests
run_tests() {
    echo -e "${YELLOW}Running tests before deployment...${NC}"

    cd move

    if sui move test; then
        echo -e "${GREEN}All tests passed${NC}"
        cd ..
        return 0
    else
        echo -e "${RED}Tests failed. Fix issues before deploying to mainnet.${NC}"
        cd ..
        return 1
    fi
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

# Function to estimate gas cost
estimate_gas_cost() {
    echo -e "${YELLOW}Estimating deployment gas cost...${NC}"

    cd move

    # Dry run to estimate gas
    local dry_run=$(sui client publish --dry-run --skip-dependency-verification 2>&1)

    if echo "$dry_run" | grep -q "gas_used"; then
        local gas_estimate=$(echo "$dry_run" | grep "gas_used" | awk '{print $2}')
        echo -e "${BLUE}Estimated gas: $gas_estimate MIST${NC}"

        # Convert to SUI (1 SUI = 1,000,000,000 MIST)
        local sui_cost=$(echo "scale=6; $gas_estimate / 1000000000" | bc)
        echo -e "${BLUE}Estimated cost: $sui_cost SUI${NC}"

        echo ""
        read -p "Proceed with deployment? (yes/no): " proceed
        if [ "$proceed" != "yes" ]; then
            echo -e "${RED}Deployment cancelled.${NC}"
            cd ..
            exit 0
        fi
    fi

    cd ..
}

# Function to deploy the package
deploy_package() {
    echo -e "${PURPLE}Deploying SuiWorld package to MAINNET...${NC}"

    cd move

    # Final confirmation
    echo -e "${RED}FINAL CONFIRMATION: Deploy to mainnet?${NC}"
    read -p "Type 'DEPLOY' to confirm: " final_confirm

    if [ "$final_confirm" != "DEPLOY" ]; then
        echo -e "${RED}Deployment cancelled.${NC}"
        cd ..
        exit 0
    fi

    # Deploy with high gas budget
    echo "Deploying with gas budget: 1000000000 MIST (1 SUI)"

    DEPLOY_OUTPUT=$(sui client publish --gas-budget 1000000000 --skip-dependency-verification 2>&1)

    if echo "$DEPLOY_OUTPUT" | grep -q "Successfully"; then
        echo -e "${GREEN}Package deployed successfully to MAINNET!${NC}"

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
            echo "NETWORK=$NETWORK" > .env.mainnet
            echo "PACKAGE_ID=$PACKAGE_ID" >> .env.mainnet
            echo "DEPLOYER=$(sui client active-address)" >> .env.mainnet
            echo "RPC_URL=$RPC_URL" >> .env.mainnet
            echo "DEPLOY_TIME=$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> .env.mainnet
            echo "DEPLOY_TX=$(echo "$DEPLOY_OUTPUT" | grep -oE "Transaction digest: 0x[a-f0-9]+" | cut -d' ' -f3)" >> .env.mainnet

            # Save package ID separately for easy access
            echo "$PACKAGE_ID" > deployed_package_mainnet.txt

            # Save full deployment output for reference
            echo "$DEPLOY_OUTPUT" > deployment_mainnet.log

            echo -e "${GREEN}Deployment info saved to:${NC}"
            echo "  - .env.mainnet (environment variables)"
            echo "  - deployed_package_mainnet.txt (package ID)"
            echo "  - deployment_mainnet.log (full output)"

            # Extract and save important object IDs
            echo -e "${YELLOW}Extracting created objects...${NC}"
            echo "" >> .env.mainnet
            echo "# Created Objects" >> .env.mainnet

            # Parse created objects from deployment output
            if echo "$DEPLOY_OUTPUT" | grep -q "Created Objects:"; then
                echo "$DEPLOY_OUTPUT" | sed -n '/Created Objects:/,/^$/p' >> deployment_objects_mainnet.txt
                echo -e "${GREEN}Object IDs saved to deployment_objects_mainnet.txt${NC}"
            fi

            # Create deployment record
            create_deployment_record

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

# Function to create deployment record
create_deployment_record() {
    echo -e "${YELLOW}Creating deployment record...${NC}"

    cat > deployment_record_mainnet.json << EOF
{
  "network": "$NETWORK",
  "packageId": "$PACKAGE_ID",
  "deployer": "$(sui client active-address)",
  "deployTime": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")",
  "rpcUrl": "$RPC_URL",
  "version": "1.0.0",
  "modules": [
    "token",
    "manager_nft",
    "message",
    "vote",
    "swap",
    "rewards",
    "slashing"
  ]
}
EOF

    echo -e "${GREEN}Deployment record saved to deployment_record_mainnet.json${NC}"
}

# Function to verify deployment
verify_deployment() {
    echo -e "${YELLOW}Verifying deployment...${NC}"

    if [ ! -f "deployed_package_mainnet.txt" ]; then
        echo -e "${RED}Package ID file not found${NC}"
        return 1
    fi

    PACKAGE_ID=$(cat deployed_package_mainnet.txt)

    echo "Fetching package info..."
    sui client object $PACKAGE_ID

    echo -e "${GREEN}Deployment verified on mainnet${NC}"
}

# Function to display post-deployment information
show_post_deployment() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   🎉 MAINNET DEPLOYMENT SUCCESSFUL! 🎉   ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    if [ -f "deployed_package_mainnet.txt" ]; then
        PACKAGE_ID=$(cat deployed_package_mainnet.txt)
        echo -e "${PURPLE}Package ID:${NC} $PACKAGE_ID"
    fi

    echo -e "${PURPLE}Network:${NC} Mainnet"
    echo -e "${PURPLE}RPC URL:${NC} $RPC_URL"
    echo -e "${PURPLE}Explorer:${NC} https://suiexplorer.com/object/$PACKAGE_ID?network=mainnet"
    echo ""
    echo -e "${GREEN}✅ CRITICAL POST-DEPLOYMENT STEPS:${NC}"
    echo ""
    echo "1. 📋 SAVE YOUR PACKAGE ID:"
    echo "   $PACKAGE_ID"
    echo ""
    echo "2. 🔐 SECURE YOUR DEPLOYMENT FILES:"
    echo "   - Backup: .env.mainnet"
    echo "   - Backup: deployed_package_mainnet.txt"
    echo "   - Backup: deployment_mainnet.log"
    echo "   - Backup: deployment_record_mainnet.json"
    echo ""
    echo "3. 🌐 VERIFY ON EXPLORER:"
    echo "   https://suiexplorer.com/object/$PACKAGE_ID?network=mainnet"
    echo ""
    echo "4. 🔧 UPDATE FRONTEND:"
    echo "   - Update .env with mainnet Package ID"
    echo "   - Update RPC endpoints to mainnet"
    echo "   - Test all interactions thoroughly"
    echo ""
    echo "5. 📢 ANNOUNCE DEPLOYMENT:"
    echo "   - Update documentation with mainnet addresses"
    echo "   - Notify community of mainnet launch"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT SECURITY NOTES:${NC}"
    echo "- Never share private keys or mnemonics"
    echo "- Monitor contract interactions regularly"
    echo "- Set up alerts for unusual activity"
    echo "- Consider using multisig for admin functions"
    echo ""
}

# Main deployment flow
main() {
    echo "Starting MAINNET deployment process..."
    echo ""

    # Step 1: Security checks
    security_checks

    # Step 2: Setup mainnet environment
    setup_mainnet_env

    # Step 3: Check balance
    check_balance

    # Step 4: Update Move.toml
    update_move_toml

    # Step 5: Run tests
    if ! run_tests; then
        echo -e "${RED}Tests failed. Cannot deploy to mainnet.${NC}"
        exit 1
    fi

    # Step 6: Build package
    if ! build_package; then
        echo -e "${RED}Build failed. Cannot deploy to mainnet.${NC}"
        exit 1
    fi

    # Step 7: Estimate gas cost
    estimate_gas_cost

    # Step 8: Deploy package
    if ! deploy_package; then
        echo -e "${RED}Deployment failed.${NC}"
        exit 1
    fi

    # Step 9: Verify deployment
    verify_deployment

    # Step 10: Show post-deployment information
    show_post_deployment
}

# Run main function
main