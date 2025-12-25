#!/bin/bash
# OSX Cleaner Uninstallation Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="$HOME/Library/Application Support/osxcleaner"

echo -e "${YELLOW}OSX Cleaner Uninstallation${NC}"
echo "==========================="
echo ""

# Remove binary
remove_binary() {
    if [ -f "$INSTALL_DIR/osxcleaner" ]; then
        echo -e "${YELLOW}Removing osxcleaner binary...${NC}"
        sudo rm -f "$INSTALL_DIR/osxcleaner"
        echo -e "${GREEN}✓ Binary removed${NC}"
    else
        echo "Binary not found at $INSTALL_DIR/osxcleaner"
    fi
}

# Remove configuration
remove_config() {
    if [ -d "$CONFIG_DIR" ]; then
        echo -e "${YELLOW}Remove configuration? [y/N]${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            echo -e "${GREEN}✓ Configuration removed${NC}"
        else
            echo "Configuration kept at $CONFIG_DIR"
        fi
    fi
}

# Remove launchd agent
remove_launchd() {
    local plist="$HOME/Library/LaunchAgents/com.osxcleaner.agent.plist"
    if [ -f "$plist" ]; then
        echo -e "${YELLOW}Removing launchd agent...${NC}"
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
        echo -e "${GREEN}✓ launchd agent removed${NC}"
    fi
}

# Main
main() {
    remove_launchd
    remove_binary
    remove_config

    echo ""
    echo -e "${GREEN}Uninstallation complete!${NC}"
}

main "$@"
