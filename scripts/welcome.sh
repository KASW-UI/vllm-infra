#!/usr/bin/env bash
set -uo pipefail

source /home/dev/.config/cpu-vllm-infra/torch.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/vllm.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/docker.env 2>/dev/null || true

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BOLD="\033[1m"
RESET="\033[0m"

MISSING=()
WARN=()
OK=0
TOTAL=0

check() {
    local name="$1"
    shift
    ((TOTAL++))
    if "$@" 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} $name"
        ((OK++))
        return 0
    else
        echo -e "  ${RED}✗${RESET} $name"
        MISSING+=("$name")
        return 1
    fi
}

warn() {
    local name="$1" msg="$2"
    echo -e "  ${YELLOW}⚠${RESET} $name — $msg"
    WARN+=("$name")
}

echo -e "${BOLD}========================================${RESET}"
echo -e "${BOLD}  vLLM CPU Inference — Dependency Check${RESET}"
echo -e "${BOLD}========================================${RESET}"
echo

# ── System ──
echo -e "${BOLD}[System]${RESET}"
check "gcc-13"        command -v gcc-13
check "cmake"         cmake --version
check "ninja"         ninja --version
check "tcmalloc"      ldconfig -p 2>/dev/null | grep -q libtcmalloc
check "numa"          [ -f /usr/lib/x86_64-linux-gnu/libnuma.so ]
echo

# ── Python ──
echo -e "${BOLD}[Python]${RESET}"
check "python3.12"    python3.12 --version
check "pip"           pip --version
echo

# ── PyTorch ──
echo -e "${BOLD}[PyTorch]${RESET}"
check "torch+cpu"     python -c "import torch; print(torch.__version__)"
check "torchvision"   python -c "import torchvision"
check "torchaudio"    python -c "import torchaudio"
check "intel-openmp"  python -c "import intel_openmp"
echo

# ── vLLM ──
echo -e "${BOLD}[vLLM]${RESET}"
check "vllm (LLM)"    python -c "from vllm import LLM"
check "vllm version"  python -c "import vllm; print(vllm.__version__)"
echo

# ── Serving ──
echo -e "${BOLD}[Serving Stack]${RESET}"
check "transformers"       python -c "import transformers"
check "safetensors"        python -c "import safetensors"
check "fastapi"            python -c "import fastapi"
check "uvicorn"            python -c "import uvicorn"
check "xgrammar"           python -c "import xgrammar"
check "tokenizers"         python -c "import tokenizers"
check "sentencepiece"      python -c "import sentencepiece"
check "tiktoken"           python -c "import tiktoken"
check "compressed-tensors" python -c "import compressed_tensors"
echo

# ── Numerical ──
echo -e "${BOLD}[Numerical]${RESET}"
check "numpy"         python -c "import numpy"
check "numba"         python -c "import numba"
check "mpmath"        python -c "import mpmath"
check "networkx"      python -c "import networkx"
echo

# ── Build tools ──
echo -e "${BOLD}[Build Tools]${RESET}"
check "setuptools"      python -c "import setuptools"
check "setuptools-scm"  python -c "import setuptools_scm"
check "setuptools-rust" python -c "import setuptools_rust"
check "wheel"           python -c "import wheel"
check "jinja2"          python -c "import jinja2"
check "packaging"       python -c "import packaging"
check "regex"           python -c "import regex"
echo

# ── I/O & Networking ──
echo -e "${BOLD}[I/O & Networking]${RESET}"
check "requests"         python -c "import requests"
check "httpx"            python -c "import httpx"
check "huggingface_hub"  python -c "import huggingface_hub"
check "fsspec"           python -c "import fsspec"
check "filelock"         python -c "import filelock"
check "pyyaml"           python -c "import yaml"
check "rich"             python -c "import rich"
check "loguru"           python -c "import loguru"
check "py-cpuinfo"       python -c "import cpuinfo"
echo

# ── Utilities ──
echo -e "${BOLD}[Utilities]${RESET}"
check "psutil"        python -c "import psutil"
check "tqdm"          python -c "import tqdm"
check "pillow"        python -c "import PIL"
check "ipython"       python -c "import IPython"
check "typer"         python -c "import typer"
echo

# ── Env ──
echo -e "${BOLD}[Environment]${RESET}"
check "VLLM_TARGET_DEVICE"   [ "${VLLM_TARGET_DEVICE:-}" = "cpu" ]
check "LD_PRELOAD"            [ -n "${LD_PRELOAD:-}" ] || warn "LD_PRELOAD" "perf may degrade without tcmalloc/iomp"
check "OMP_NUM_THREADS"       [ -n "${OMP_NUM_THREADS:-}" ] || warn "OMP_NUM_THREADS" "using default thread count"
check "HF cache"              [ -d "${HF_HOME:-$HOME/.cache/huggingface}" ]
echo

# ── Summary ──
echo -e "${BOLD}========================================${RESET}"
if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}║     Welcome to My Vllm           ║${RESET}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════╝${RESET}"
    echo -e "${GREEN}All ${OK}/${TOTAL} checks passed${RESET}"
else
    echo -e "${BOLD}${RED}╔══════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${RED}║  ${#MISSING[@]} missing dependencies         ║${RESET}"
    echo -e "${BOLD}${RED}╚══════════════════════════════════╝${RESET}"
    for dep in "${MISSING[@]}"; do
        echo -e "  ${RED}✗${RESET} $dep"
    done
    echo
    echo -e "${YELLOW}Fix: VLLM_TARGET_DEVICE=cpu pip install -e /workspace/vllm --no-build-isolation${RESET}"
fi
echo

if [[ ${#MISSING[@]} -ne 0 ]]; then
    exit 1
fi
