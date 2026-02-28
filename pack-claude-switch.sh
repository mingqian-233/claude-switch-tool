#!/usr/bin/env bash
# Pack claude-switch tool into a portable directory
# Usage: ./pack-claude-switch.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_info() { echo -e "${CYAN}>>>${NC} $*"; }
_ok() { echo -e "${GREEN}>>>${NC} $*"; }
_warn() { echo -e "${YELLOW}>>>${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/dist}"
PACK_DIR="${OUTPUT_DIR}/claude-switch-tool"
TARBALL_PATH="${OUTPUT_DIR}/claude-switch-tool.tar.gz"
ZIP_PATH="${OUTPUT_DIR}/claude-switch-tool.zip"

SCRIPT_NAME="claude-switch"
WIN_SCRIPT_NAME="claude-switch.ps1"
INSTALL_SCRIPT="install-claude-switch.sh"
WIN_INSTALL_PS1="install-claude-switch.ps1"
WIN_INSTALL_CMD="install-claude-switch.cmd"
PACK_SCRIPT="pack-claude-switch.sh"
README_FILE="README.md"

_info "Creating package directory..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$PACK_DIR"
mkdir -p "$PACK_DIR"

for required in "$SCRIPT_NAME" "$INSTALL_SCRIPT" "$PACK_SCRIPT" "$README_FILE"; do
    if [ ! -f "${SCRIPT_DIR}/${required}" ]; then
        echo -e "${RED}error:${NC} 缺少必需文件: ${SCRIPT_DIR}/${required}" >&2
        exit 1
    fi
done

_info "Copying Linux scripts..."
cp "${SCRIPT_DIR}/${SCRIPT_NAME}" "$PACK_DIR/$SCRIPT_NAME"
cp "${SCRIPT_DIR}/${INSTALL_SCRIPT}" "$PACK_DIR/$INSTALL_SCRIPT"
cp "${SCRIPT_DIR}/${PACK_SCRIPT}" "$PACK_DIR/$PACK_SCRIPT"

_info "Copying README..."
cp "${SCRIPT_DIR}/${README_FILE}" "$PACK_DIR/README.md"

# Copy native Windows main script
if [ -f "${SCRIPT_DIR}/${WIN_SCRIPT_NAME}" ]; then
    _info "Copying Windows main script (.ps1)..."
    cp "${SCRIPT_DIR}/${WIN_SCRIPT_NAME}" "$PACK_DIR/"
else
    _warn "Windows main script not found: ${WIN_SCRIPT_NAME}"
fi

# Copy Windows install scripts
if [ -f "${SCRIPT_DIR}/${WIN_INSTALL_PS1}" ]; then
    _info "Copying Windows install script (.ps1)..."
    cp "${SCRIPT_DIR}/${WIN_INSTALL_PS1}" "$PACK_DIR/"
else
    _warn "Windows installer not found: ${WIN_INSTALL_PS1}"
fi

if [ -f "${SCRIPT_DIR}/${WIN_INSTALL_CMD}" ]; then
    _info "Copying Windows install entry (.cmd)..."
    cp "${SCRIPT_DIR}/${WIN_INSTALL_CMD}" "$PACK_DIR/"
else
    _warn "Windows installer entry not found: ${WIN_INSTALL_CMD}"
fi

# Make scripts executable
chmod +x "$PACK_DIR/$SCRIPT_NAME"
chmod +x "$PACK_DIR/$INSTALL_SCRIPT"
chmod +x "$PACK_DIR/$PACK_SCRIPT"

# Create a tarball
_info "Creating tarball..."
tar -czf "$TARBALL_PATH" -C "$OUTPUT_DIR" "claude-switch-tool"

# Create a zip archive if zip is available
if command -v zip >/dev/null 2>&1; then
    _info "Creating zip archive..."
    (
        cd "$OUTPUT_DIR"
        rm -f "$ZIP_PATH"
        zip -rq "$(basename "$ZIP_PATH")" "claude-switch-tool"
    )
else
    _warn "zip not found; skipped .zip archive creation"
fi

_ok "Package created in: ${BOLD}${PACK_DIR}${NC}"
_ok "Tarball created: ${BOLD}${TARBALL_PATH}${NC}"
if [ -f "$ZIP_PATH" ]; then
    _ok "Zip created: ${BOLD}${ZIP_PATH}${NC}"
fi
echo ""
echo -e "${BOLD}Contents:${NC}"
ls -la "$PACK_DIR/"
echo ""
echo -e "${BOLD}To install on another machine:${NC}"
echo "1. Copy the tarball or directory"
echo "2. Run: ./install-claude-switch.sh"
echo "3. Use: cs"