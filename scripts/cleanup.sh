#!/usr/bin/env bash

###############################################################################
# Cleanup Script
#
# Safe cleanup for vLLM CPU Development Environment
###############################################################################

set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RESET="\033[0m"

info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[ OK ]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }

info "Cleaning apt cache..."
sudo apt autoremove -y || true
sudo apt autoclean -y || true
sudo apt clean || true

info "Cleaning systemd journal..."
sudo journalctl --vacuum-time=7d >/dev/null 2>&1 || true

if command -v pip >/dev/null 2>&1; then
    info "Cleaning pip cache..."
    pip cache purge || true
fi

if command -v uv >/dev/null 2>&1; then
    info "Cleaning uv cache..."
    uv cache clean || true
fi

info "Removing Python cache..."
find "$HOME/workspace" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$HOME/workspace" -type f -name "*.pyc" -delete 2>/dev/null || true

info "Removing CMake cache..."
find "$HOME/workspace" -type f -name "CMakeCache.txt" -delete 2>/dev/null || true
find "$HOME/workspace" -type d -name "CMakeFiles" -exec rm -rf {} + 2>/dev/null || true

info "Cleaning temporary files..."
rm -rf "$HOME/workspace/tmp/"* 2>/dev/null || true

if [[ -d "$HOME/.local/share/Trash/files" ]]; then
    info "Emptying trash..."
    rm -rf "$HOME/.local/share/Trash/files/"* 2>/dev/null || true
fi

if command -v docker >/dev/null 2>&1; then
    warn "Docker cleanup..."
    docker system prune -f || true
fi

echo
success "Cleanup completed."
echo
du -sh "$HOME/workspace" 2>/dev/null || true
echo
df -h /
echo
