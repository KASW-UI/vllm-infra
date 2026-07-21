#!/usr/bin/env bash
set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"
BOLD="\033[1m"

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✔${RESET} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✘${RESET} $1"; ((FAIL++)); }
info() { echo -e "\n${BOLD}${BLUE}── $1 ──${RESET}"; }

echo
echo -e "${BOLD}========================================================${RESET}"
echo -e "${BOLD} vLLM CPU Infrastructure Health Check${RESET}"
echo -e "${BOLD}========================================================${RESET}"

info "System"
pass "Kernel: $(uname -r)"
pass "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo 'unknown')"
pass "Architecture: $(uname -m)"

info "CPU"
CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d':' -f2 | xargs || echo "unknown")
pass "Model: ${CPU_MODEL}"
pass "Cores: $(nproc)"
pass "Threads per core: $(lscpu 2>/dev/null | grep "Thread(s) per core" | awk '{print $NF}' || echo 'N/A')"

AVX2=$(lscpu 2>/dev/null | grep -c "avx2" || echo "0")
if [[ $AVX2 -gt 0 ]]; then
    pass "AVX2: supported"
else
    fail "AVX2: not supported"
fi

AVX512=$(lscpu 2>/dev/null | grep -c "avx512" || echo "0")
if [[ $AVX512 -gt 0 ]]; then
    pass "AVX-512: supported"
else
    pass "AVX-512: not available (AVX2 fallback)"
fi

info "NUMA Topology"
if command -v numactl >/dev/null 2>&1; then
    numactl --hardware 2>/dev/null || true
    pass "numactl available"
else
    fail "numactl not found"
fi

info "Memory"
free -h
pass "Memory info displayed"

info "TCMalloc"
if ldconfig -p 2>/dev/null | grep -q libtcmalloc; then
    TCMALLOC_VER=$(ldconfig -p 2>/dev/null | grep libtcmalloc_minimal | head -1 | awk '{print $NF}')
    pass "TCMalloc: ${TCMALLOC_VER}"
else
    fail "TCMalloc not found"
fi

info "Compiler"
gcc --version 2>/dev/null | head -1 && pass "gcc OK" || fail "gcc not found"
g++ --version 2>/dev/null | head -1 && pass "g++ OK" || fail "g++ not found"

if command -v ninja >/dev/null 2>&1; then
    NINJA_VER=$(ninja --version 2>/dev/null)
    pass "ninja: ${NINJA_VER}"
else
    fail "ninja not found"
fi

if command -v cmake >/dev/null 2>&1; then
    CMAKE_VER=$(cmake --version 2>/dev/null | head -1)
    pass "cmake: ${CMAKE_VER#cmake version }"
else
    fail "cmake not found"
fi

info "Python"
if command -v python >/dev/null 2>&1; then
    PY_VER=$(python --version 2>&1)
    pass "${PY_VER}"
else
    fail "python not found"
fi

info "PyTorch CPU"
python - <<'EOF'
import sys, torch
print(f"  Torch: {torch.__version__}")
print(f"  CPU only: {not torch.cuda.is_available()}")
print(f"  MKL-DNN: {torch.backends.mkldnn.is_available()}")
print(f"  Default dtype: {torch.get_default_dtype()}")
print(f"  Num threads: {torch.get_num_threads()}")
print(f"  Num interop threads: {torch.get_num_interop_threads()}")

a = torch.randn(2048, 2048)
b = torch.randn(2048, 2048)
c = torch.mm(a, b)
print(f"  matmul(2048x2048): OK, result shape {c.shape}")
EOF
if [[ $? -eq 0 ]]; then
    pass "PyTorch CPU"
else
    fail "PyTorch CPU"
fi

info "vLLM"
python - <<'EOF'
import sys
try:
    import vllm
    print(f"  vLLM: {vllm.__version__}")
except ImportError as e:
    print(f"  Import failed: {e}")
    sys.exit(1)
EOF
if [[ $? -eq 0 ]]; then
    pass "vLLM"
else
    fail "vLLM"
fi

info "Transformers & Tokenizers"
python - <<'EOF'
import transformers, tokenizers, tiktoken
print(f"  Transformers: {transformers.__version__}")
print(f"  Tokenizers: {tokenizers.__version__}")
print(f"  Tiktoken: {tiktoken.__version__}")
EOF
if [[ $? -eq 0 ]]; then
    pass "Tokenizers"
else
    fail "Tokenizers"
fi

info "Intel OpenMP"
python - <<'EOF'
try:
    import intel_openmp
    print(f"  intel-openmp: {intel_openmp.__version__}")
except ImportError:
    import importlib.metadata
    ver = importlib.metadata.version("intel-openmp")
    print(f"  intel-openmp: {ver}")
EOF
if [[ $? -eq 0 ]]; then
    pass "Intel OpenMP"
else
    fail "Intel OpenMP"
fi

info "Serving Stack"
python - <<'EOF'
import fastapi, starlette, uvicorn
print(f"  FastAPI: {fastapi.__version__}")
print(f"  Starlette: {starlette.__version__}")
print(f"  Uvicorn: {uvicorn.__version__}")
EOF
if [[ $? -eq 0 ]]; then
    pass "Serving Stack"
else
    fail "Serving Stack"
fi

info "Disk"
df -h /workspace 2>/dev/null || df -h /

echo
echo -e "${BOLD}========================================================${RESET}"
echo -e "${GREEN}PASS: ${PASS}${RESET}  ${RED}FAIL: ${FAIL}${RESET}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed${RESET}"
else
    echo -e "${RED}✗ ${FAIL} check(s) failed${RESET}"
    exit 1
fi
echo -e "${BOLD}========================================================${RESET}"
