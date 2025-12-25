#!/bin/bash
# OSX Cleaner Installation Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}OSX Cleaner Installation${NC}"
echo "========================="
echo ""

# Check for required tools
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"

    # Check Swift
    if ! command -v swift &> /dev/null; then
        echo -e "${RED}Error: Swift is not installed${NC}"
        echo "Please install Xcode Command Line Tools:"
        echo "  xcode-select --install"
        exit 1
    fi
    echo "  ✓ Swift $(swift --version 2>&1 | head -1 | awk '{print $NF}')"

    # Check Rust
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}Error: Rust is not installed${NC}"
        echo "Please install Rust:"
        echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi
    echo "  ✓ Rust $(rustc --version | awk '{print $2}')"

    echo -e "${GREEN}All requirements met${NC}"
    echo ""
}

# Build the project
build() {
    echo -e "${YELLOW}Building OSX Cleaner...${NC}"
    cd "$PROJECT_DIR"
    make all
    echo ""
}

# Install the binary
install_binary() {
    echo -e "${YELLOW}Installing to ${INSTALL_DIR}...${NC}"

    # Create directory if needed
    if [ ! -d "$INSTALL_DIR" ]; then
        sudo mkdir -p "$INSTALL_DIR"
    fi

    # Copy binary
    sudo cp "$PROJECT_DIR/.build/release/osxcleaner" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/osxcleaner"

    echo -e "${GREEN}Installed osxcleaner to ${INSTALL_DIR}${NC}"
    echo ""
}

# Verify installation
verify() {
    echo -e "${YELLOW}Verifying installation...${NC}"

    if command -v osxcleaner &> /dev/null; then
        echo -e "${GREEN}✓ osxcleaner installed successfully${NC}"
        osxcleaner --version
    else
        echo -e "${YELLOW}Note: You may need to add ${INSTALL_DIR} to your PATH${NC}"
        echo "Add this to your ~/.zshrc or ~/.bashrc:"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    fi
    echo ""
}

# Main
main() {
    check_requirements
    build
    install_binary
    verify

    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "Usage:"
    echo "  osxcleaner analyze     # Analyze disk usage"
    echo "  osxcleaner clean       # Clean up caches"
    echo "  osxcleaner --help      # Show help"
}

main "$@"
