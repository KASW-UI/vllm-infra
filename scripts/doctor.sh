#!/usr/bin/env bash

###############################################################################
# Environment Doctor
#
# Comprehensive diagnostic overview of the vLLM CPU environment
###############################################################################

set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"
BOLD="\033[1m"

info() { echo -e "\n${BOLD}${BLUE}── $1 ──${RESET}"; }
pass() { echo -e "  ${GREEN}✔${RESET} $1"; }

echo
echo -e "${BOLD}========================================================${RESET}"
echo -e "${BOLD} vLLM CPU Environment Doctor${RESET}"
echo -e "${BOLD}========================================================${RESET}"

info "System Overview"
pass "Hostname: $(hostname)"
pass "Kernel: $(uname -r)"
pass "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo unknown)"
pass "Uptime: $(uptime -p)"

info "CPU"
pass "Model: $(lscpu 2>/dev/null | grep 'Model name' | cut -d':' -f2 | xargs)"
pass "Sockets: $(lscpu 2>/dev/null | grep 'Socket(s)' | awk '{print $NF}')"
pass "Cores: $(nproc)"
pass "L1d: $(lscpu 2>/dev/null | grep 'L1d' | awk '{print $NF}')"
pass "L2: $(lscpu 2>/dev/null | grep 'L2' | awk '{print $NF}')"
pass "L3: $(lscpu 2>/dev/null | grep 'L3' | awk '{print $NF}')"

info "Memory"
free -h

info "NUMA"
numactl --hardware 2>/dev/null || echo "  numactl not available"

info "Disk"
df -h / /workspace 2>/dev/null || df -h /

info "Tools"
for tool in gcc g++ cmake ninja python pip uv; do
    if command -v $tool >/dev/null 2>&1; then
        pass "$tool: $(command -v $tool)"
    else
        pass "$tool: not found"
    fi
done

info "Python Version"
python --version 2>&1
pass "Python path: $(which python)"

info "Key Python Packages"
for pkg in torch vllm transformers numpy fastapi uvicorn cmake ninja numba xgrammar; do
    python -c "import $pkg; print(f'  $pkg: {$pkg.__version__}')" 2>/dev/null || \
    python -c "import importlib.metadata; print(f'  $pkg: {importlib.metadata.version(\"$pkg\")}')" 2>/dev/null || \
    echo "  $pkg: not installed"
done

info "Environment Variables"
for var in OMP_NUM_THREADS LD_PRELOAD VLLM_CPU_KVCACHE_SPACE MKL_NUM_THREADS CC CXX; do
    if [[ -n "${!var:-}" ]]; then
        pass "$var=${!var}"
    else
        pass "$var: (unset)"
    fi
done

info "HF Cache"
if [[ -d ~/.cache/huggingface ]]; then
    du -sh ~/.cache/huggingface 2>/dev/null || pass "HF cache: exists"
else
    pass "HF cache: no local cache"
fi

echo
echo -e "${BOLD}========================================================${RESET}"
echo -e "${GREEN}Doctor check complete.${RESET}"
echo -e "${BOLD}========================================================${RESET}"
echo
