#!/bin/bash

# SuiWorld Content Hashing Helper Script
# This script helps generate hashes for message content

echo "======================================"
echo "SuiWorld Content Hash Generator"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to generate hash
generate_hash() {
    local content="$1"
    echo -n "$content" | sha256sum | cut -d' ' -f1
}

# Function to generate hash in hex format for Sui
generate_hex_hash() {
    local content="$1"
    local hash=$(generate_hash "$content")
    echo "0x$hash"
}

# Interactive mode
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Enter the content to hash (or 'exit' to quit):${NC}"

    while true; do
        echo ""
        echo -n "Title: "
        read -r title

        if [ "$title" = "exit" ]; then
            break
        fi

        echo -n "Content: "
        read -r content

        if [ "$content" = "exit" ]; then
            break
        fi

        TITLE_HASH=$(generate_hex_hash "$title")
        CONTENT_HASH=$(generate_hex_hash "$content")

        echo ""
        echo -e "${GREEN}Generated Hashes:${NC}"
        echo -e "${BLUE}Title Hash:${NC} $TITLE_HASH"
        echo -e "${BLUE}Content Hash:${NC} $CONTENT_HASH"
        echo ""
        echo "Use these values in your Sui command:"
        echo -e "${YELLOW}sui client call \\
    --package <PACKAGE_ID> \\
    --module message \\
    --function create_message \\
    --args <BOARD_ID> <SWT_COIN> $TITLE_HASH $CONTENT_HASH '[]' \\
    --gas-budget 10000000${NC}"
    done

# Command line arguments mode
else
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage:"
        echo "  $0                    # Interactive mode"
        echo "  $0 <title> <content>  # Direct mode"
        echo "  $0 --help            # Show this help"
        echo ""
        echo "Example:"
        echo "  $0 \"Hello World\" \"This is my first message\""
        exit 0
    fi

    if [ $# -ne 2 ]; then
        echo -e "${YELLOW}Error: Please provide both title and content${NC}"
        echo "Usage: $0 <title> <content>"
        exit 1
    fi

    TITLE="$1"
    CONTENT="$2"

    TITLE_HASH=$(generate_hex_hash "$TITLE")
    CONTENT_HASH=$(generate_hex_hash "$CONTENT")

    echo -e "${GREEN}Input:${NC}"
    echo "Title: $TITLE"
    echo "Content: $CONTENT"
    echo ""
    echo -e "${GREEN}Generated Hashes:${NC}"
    echo -e "${BLUE}Title Hash:${NC} $TITLE_HASH"
    echo -e "${BLUE}Content Hash:${NC} $CONTENT_HASH"
fi

echo ""
echo -e "${YELLOW}Remember to store the original content off-chain!${NC}"