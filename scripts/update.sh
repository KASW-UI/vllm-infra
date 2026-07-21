#!/usr/bin/env bash

###############################################################################
# Update Script
#
# Updates system packages and Python dependencies
###############################################################################

set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
RESET="\033[0m"

info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[ OK ]${RESET} $1"; }

info "Updating apt packages..."
sudo apt update && sudo apt upgrade -y || true

info "Updating pip..."
pip install --upgrade pip setuptools wheel || true

if command -v uv >/dev/null 2>&1; then
    info "Updating uv..."
    uv self update || true
fi

success "Update completed."
