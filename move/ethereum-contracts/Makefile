# Makefile for SuiWorld Ethereum Contracts

# Load environment variables
include .env
export

# Colors for terminal output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

.PHONY: help install build test deploy deploy-sepolia clean format

help:
	@echo "$(GREEN)SuiWorld Ethereum Contracts - Available Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup:$(NC)"
	@echo "  make install       - Install dependencies"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  make build         - Compile contracts"
	@echo "  make test          - Run all tests"
	@echo "  make test-v        - Run tests with verbose output"
	@echo "  make test-gas      - Run tests with gas reporting"
	@echo "  make coverage      - Generate test coverage report"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@echo "  make deploy-local  - Deploy to local Anvil node"
	@echo "  make deploy-sepolia - Deploy to Sepolia testnet"
	@echo "  make setup-ntt     - Setup NTT Manager (after NTT deployment)"
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@echo "  make clean         - Remove build artifacts"
	@echo "  make format        - Format Solidity code"
	@echo "  make anvil         - Start local Anvil node"
	@echo ""

# Install dependencies
install:
	@echo "$(GREEN)Installing dependencies...$(NC)"
	forge install

# Build contracts
build:
	@echo "$(GREEN)Building contracts...$(NC)"
	forge build

# Run tests
test:
	@echo "$(GREEN)Running tests...$(NC)"
	forge test

# Run tests with verbose output
test-v:
	@echo "$(GREEN)Running tests (verbose)...$(NC)"
	forge test -vvv

# Run tests with gas reporting
test-gas:
	@echo "$(GREEN)Running tests with gas report...$(NC)"
	forge test --gas-report

# Generate coverage report
coverage:
	@echo "$(GREEN)Generating coverage report...$(NC)"
	forge coverage

# Deploy to local Anvil
deploy-local:
	@echo "$(GREEN)Deploying to local Anvil...$(NC)"
	forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast -vvv

# Deploy to Sepolia
deploy-sepolia:
	@echo "$(GREEN)Deploying to Sepolia testnet...$(NC)"
	@echo "$(YELLOW)Make sure you have:$(NC)"
	@echo "  1. SEPOLIA_RPC_URL set in .env"
	@echo "  2. PRIVATE_KEY set in .env"
	@echo "  3. Enough Sepolia ETH for gas"
	@echo ""
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(SEPOLIA_RPC_URL) --broadcast -vvv

# Setup NTT Manager (run after NTT deployment)
setup-ntt:
	@echo "$(GREEN)Setting up NTT Manager...$(NC)"
	@echo "$(YELLOW)Make sure you have:$(NC)"
	@echo "  1. TOKEN_ADDRESS set in .env"
	@echo "  2. NTT_MANAGER_ADDRESS set in .env"
	@echo ""
	forge script script/SetupNTT.s.sol:SetupNTTScript --rpc-url $(SEPOLIA_RPC_URL) --broadcast -vvv

# Clean build artifacts
clean:
	@echo "$(GREEN)Cleaning build artifacts...$(NC)"
	forge clean
	rm -rf cache out

# Format code
format:
	@echo "$(GREEN)Formatting code...$(NC)"
	forge fmt

# Start local Anvil node
anvil:
	@echo "$(GREEN)Starting Anvil...$(NC)"
	anvil --host 0.0.0.0

.DEFAULT_GOAL := help