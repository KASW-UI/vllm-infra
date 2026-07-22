#!/usr/bin/env bash

###############################################################################
# vLLM CPU Development Environment Verification
#
# Detects container vs bare-metal and adjusts checks accordingly.
###############################################################################

set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✔${RESET} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✘${RESET} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
info() { echo -e "\n${BLUE}[INFO]${RESET} $1"; }

IS_CONTAINER=false
if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    IS_CONTAINER=true
fi

echo
echo "======================================================"
if $IS_CONTAINER; then
    echo " vLLM CPU Environment Verification (Container Mode)"
else
    echo " vLLM CPU Environment Verification"
fi
echo "======================================================"
echo

################################################################################
# CPU Architecture
################################################################################

info "Checking CPU Architecture..."

ARCH=$(uname -m)
pass "Architecture: ${ARCH}"

CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d':' -f2 | xargs || echo "unknown")
pass "CPU: ${CPU_MODEL}"

CORES=$(nproc)
pass "Cores: ${CORES}"

# Check ISA features
if lscpu 2>/dev/null | grep -q "avx2"; then
    pass "AVX2 supported"
else
    fail "AVX2 not supported (vLLM CPU minimum requirement)"
fi

if lscpu 2>/dev/null | grep -q "avx512f"; then
    pass "AVX-512 supported (recommended)"
else
    warn "AVX-512 not available (AVX2 fallback)"
fi

################################################################################
# Compiler
################################################################################

info "Checking Compilers..."

if command -v gcc >/dev/null 2>&1; then
    GCC_VER=$(gcc --version | head -1)
    pass "gcc: ${GCC_VER}"
else
    fail "gcc not found"
fi

if command -v g++ >/dev/null 2>&1; then
    GXX_VER=$(g++ --version | head -1)
    pass "g++: ${GXX_VER}"
else
    fail "g++ not found"
fi

################################################################################
# NUMA
################################################################################

info "Checking NUMA Support..."

if command -v numactl >/dev/null 2>&1; then
    numactl --hardware >/tmp/numa.txt 2>&1
    NUM_NODES=$(grep -c "node" /tmp/numa.txt 2>/dev/null || echo "0")
    pass "numactl available, ${NUM_NODES} NUMA node(s)"
else
    warn "numactl not found"
fi

if ldconfig -p 2>/dev/null | grep -q libtcmalloc; then
    pass "TCMalloc library found"
else
    warn "TCMalloc library not found"
fi

################################################################################
# Python
################################################################################

info "Checking Python..."

if command -v python >/dev/null 2>&1; then
    PY_VER=$(python --version 2>&1)
    pass "${PY_VER}"
else
    fail "python not found"
fi

################################################################################
# PyTorch CPU
################################################################################

info "Checking PyTorch..."

python - <<'EOF'
import sys, torch

print(f"  Torch: {torch.__version__}")
print(f"  CPU only: {not torch.cuda.is_available()}")
print(f"  MKL available: {torch.backends.mkldnn.is_available()}")

# Quick CPU tensor test
a = torch.randn(1024, 1024)
b = torch.randn(1024, 1024)
c = torch.mm(a, b)
print(f"  Tensor test: matmul(1024x1024) OK")

print(f"  Num threads: {torch.get_num_threads()}")
EOF

if [[ $? == 0 ]]; then
    pass "PyTorch CPU"
else
    fail "PyTorch CPU"
fi

################################################################################
# vLLM
################################################################################

info "Checking vLLM..."

python - <<'EOF'
import sys
try:
    import vllm
    print(f"  vLLM: {vllm.__version__}")
except ImportError as e:
    print(f"  Import failed: {e}")
    sys.exit(1)
EOF

if [[ $? == 0 ]]; then
    pass "vLLM import"
else
    fail "vLLM import"
fi

################################################################################
# Transformers
################################################################################

info "Checking Transformers..."

python - <<'EOF'
import transformers
print(f"  Transformers: {transformers.__version__}")
EOF

if [[ $? == 0 ]]; then
    pass "Transformers"
else
    fail "Transformers"
fi

################################################################################
# Intel OpenMP
################################################################################

info "Checking Intel OpenMP..."

python - <<'EOF'
try:
    import intel_openmp
    print(f"  intel-openmp: {intel_openmp.__version__}")
except ImportError:
    try:
        import importlib.metadata
        ver = importlib.metadata.version("intel-openmp")
        print(f"  intel-openmp: {ver}")
    except Exception:
        print("  intel-openmp: not found")
EOF

if [[ $? == 0 ]]; then
    pass "Intel OpenMP"
else
    warn "Intel OpenMP not found (x86_64 recommended)"
fi

################################################################################
# FastAPI
################################################################################

info "Checking FastAPI..."

python - <<'EOF'
import fastapi
print(f"  FastAPI: {fastapi.__version__}")
EOF

if [[ $? == 0 ]]; then
    pass "FastAPI"
else
    fail "FastAPI"
fi

################################################################################
# Docker (skip in container)
################################################################################

if ! $IS_CONTAINER; then
    if command -v docker >/dev/null 2>&1; then
        info "Checking Docker..."
        if docker run --rm hello-world >/dev/null 2>&1; then
            pass "Docker"
        else
            fail "Docker"
        fi
    fi
fi

################################################################################
# Disk
################################################################################

info "Disk Usage"
df -h /workspace 2>/dev/null || df -h /

################################################################################
# Finish
################################################################################

echo
echo "======================================================"
echo -e "${GREEN}PASS: ${PASS}${RESET}  ${RED}FAIL: ${FAIL}${RESET}"

if [[ $FAIL -eq 0 ]]; then
    pass "Verification completed."
else
    fail "Verification failed with ${FAIL} error(s)."
    exit 1
fi
echo "======================================================"
echo
