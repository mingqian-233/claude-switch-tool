#!/usr/bin/env bash
# Install script for claude-switch tool
# Usage: ./install-claude-switch.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_info() { echo -e "${CYAN}>>>${NC} $*"; }
_ok() { echo -e "${GREEN}>>>${NC} $*"; }
_warn() { echo -e "${YELLOW}>>>${NC} $*"; }
_die() { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

# Determine the directory where this install script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/claude-switch"

# Check that the source script exists
[ -f "$SOURCE_SCRIPT" ] || _die "找不到 ${SOURCE_SCRIPT}，请确保 claude-switch 文件在同一目录下"

# Check if running as root (for system-wide install)
if [ "$EUID" -ne 0 ]; then
    _warn "Not running as root. Will install to ~/.local/bin instead."
    INSTALL_PREFIX="${HOME}/.local"
else
    INSTALL_PREFIX="/usr/local"
fi

BIN_DIR="${INSTALL_PREFIX}/bin"
SCRIPT_NAME="claude-switch"
ALIAS_NAME="cs"

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Copy the script directly from the repo
_info "Installing ${BOLD}${SCRIPT_NAME}${NC} to ${BIN_DIR}/..."
cp "$SOURCE_SCRIPT" "${BIN_DIR}/${SCRIPT_NAME}"
chmod +x "${BIN_DIR}/${SCRIPT_NAME}"

# Create alias/symlink
_info "Creating alias ${BOLD}${ALIAS_NAME}${NC}..."
ln -sf "${BIN_DIR}/${SCRIPT_NAME}" "${BIN_DIR}/${ALIAS_NAME}"
chmod +x "${BIN_DIR}/${ALIAS_NAME}"

# Check if bin directory is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${BIN_DIR}$"; then
    _warn "${BIN_DIR} is not in your PATH. You may need to add it."
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"${BIN_DIR}:\$PATH\""
fi

_ok "Installation complete!"
echo ""
echo -e "${BOLD}Available commands:${NC}"
echo "  ${SCRIPT_NAME}     - Main script with all features"
echo "  ${ALIAS_NAME}      - Short alias for ${SCRIPT_NAME}"
echo ""
echo -e "${BOLD}Usage examples:${NC}"
echo "  ${ALIAS_NAME}                # Interactive account selection"
echo "  ${ALIAS_NAME} login [name]   # Login and save account"
echo "  ${ALIAS_NAME} save <name>    # Save current account"
echo "  ${ALIAS_NAME} ls             # List saved accounts"
echo "  ${ALIAS_NAME} usage          # Show current usage"
echo "  ${ALIAS_NAME} usage-all      # Show all accounts' usage"
echo "  ${ALIAS_NAME} check          # Check account availability"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "1. Run ${ALIAS_NAME} login to save your current account"
echo "2. Or run ${ALIAS_NAME} save <name> if already logged in"
echo "3. Use ${ALIAS_NAME} to switch between accounts interactively"
