#!/usr/bin/env bash

###############################################################################
# vLLM CPU One-Click Install Script
#
# Supported: Ubuntu 22.04 / 24.04
# Installs:  Python 3.12, PyTorch CPU, vLLM, opencode, dev tools
# Usage:     bash install.sh
###############################################################################

set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"
BOLD="\033[1m"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VLLM_SRC="${VLLM_SRC:-/mnt/vllm}"
VLLM_REF="${VLLM_REF:-}"
VENV_DIR="${VENV_DIR:-$HOME/workspace/vllm-venv}"
GITHUB_PROXY="${GITHUB_PROXY:-https://mirror.ghproxy.com/}"

info()  { echo -e "${BOLD}${BLUE}[INFO]${RESET} $1"; }
pass()  { echo -e "  ${GREEN}✔${RESET} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail()  { echo -e "  ${RED}✘${RESET} $1"; exit 1; }

################################################################################
# Preflight
################################################################################

echo
echo -e "${BOLD}========================================================${RESET}"
echo -e "${BOLD} vLLM CPU Environment Installer${RESET}"
echo -e "${BOLD}========================================================${RESET}"
echo

if [[ $EUID -eq 0 ]]; then
    warn "Running as root. Proceeding anyway..."
fi

OS_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
ARCH=$(uname -m)

echo "Detected: $OS_ID $OS_VERSION ($ARCH)"
echo "Kernel: $KERNEL"
echo

if [[ "$OS_ID" != "ubuntu" ]]; then
    fail "Only Ubuntu 22.04 / 24.04 is supported. Detected: $OS_ID"
fi

if [[ "$OS_VERSION" != "22.04" && "$OS_VERSION" != "24.04" ]]; then
    fail "Ubuntu version $OS_VERSION not supported. Use 22.04 or 24.04."
fi

if lscpu 2>/dev/null | grep -q "avx2"; then
    pass "CPU supports AVX2 (minimum required)"
else
    fail "CPU does not support AVX2. vLLM CPU requires AVX2 or newer."
fi

################################################################################
# System Packages
################################################################################

info "Installing system packages..."

sudo apt-get update -qq

sudo apt-get install -y --no-install-recommends software-properties-common

PACKAGES=(
    ca-certificates curl wget software-properties-common
    make git git-lfs
    ninja-build
    libssl-dev libffi-dev zlib1g-dev
    libnuma-dev libtcmalloc-minimal4 numactl
    ffmpeg libsm6 libxext6 libgl1
    vim tmux htop
    jq ripgrep fd-find bat fzf
    zsh
    openssh-client
)

install_gcc() {
    # Try PPA for exact gcc-13 (matches host 13.4.0), fallback to distro default
    if add-apt-repository -y ppa:ubuntu-toolchain-r/test 2>/dev/null; then
        sudo apt-get update -qq
        if sudo apt-get install -y --no-install-recommends gcc-13 g++-13 2>/dev/null; then
            CC_BIN=gcc-13; CXX_BIN=g++-13
            return 0
        fi
    fi
    # Fallback: distro default
    if [[ "$OS_VERSION" == "24.04" ]]; then
        sudo apt-get install -y --no-install-recommends gcc-13 g++-13 2>/dev/null && CC_BIN=gcc-13 CXX_BIN=g++-13 && return 0
    else
        sudo apt-get install -y --no-install-recommends gcc-12 g++-12 2>/dev/null && CC_BIN=gcc-12 CXX_BIN=g++-12 && return 0
    fi
}

if [[ "$OS_VERSION" == "24.04" ]]; then
    PACKAGES+=(python3.12 python3.12-venv python3.12-dev)
    PYTHON_BIN=python3.12
else
    # Ubuntu 22.04: python3.12 from deadsnakes PPA
    if ! dpkg -l python3.12 2>/dev/null | grep -q '^ii'; then
        info "Adding deadsnakes PPA for Python 3.12..."
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev
    fi
    PYTHON_BIN=python3.12
fi

sudo apt-get install -y --no-install-recommends "${PACKAGES[@]}"

if ! command -v btop &>/dev/null; then
    BTOP_VER=1.4.0
    BTOP_URLS=(
        "${GITHUB_PROXY}https://github.com/aristocratos/btop/releases/download/v${BTOP_VER}/btop-x86_64-linux-musl.tbz"
        "https://github.com/aristocratos/btop/releases/download/v${BTOP_VER}/btop-x86_64-linux-musl.tbz"
    )
    info "Installing btop ${BTOP_VER}..."
    FOUND_BTOP=false
    for url in "${BTOP_URLS[@]}"; do
        if curl -fSL --retry 2 -o /tmp/btop.tbz "$url" 2>/dev/null; then
            tar xf /tmp/btop.tbz -C /tmp
            sudo mv /tmp/btop/bin/btop /usr/local/bin/btop
            rm -f /tmp/btop.tbz
            FOUND_BTOP=true
            break
        fi
    done
    if $FOUND_BTOP; then
        pass "btop ${BTOP_VER} installed"
    else
        warn "btop download failed, skipping"
    fi
fi

install_gcc
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/$CC_BIN 100 2>/dev/null || true
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/$CXX_BIN 100 2>/dev/null || true

pass "System packages installed"
pass "Compiler: $(gcc --version | head -1)"

################################################################################
# Python venv
################################################################################

info "Setting up Python virtual environment..."

if [[ ! -d "$VENV_DIR" ]]; then
    $PYTHON_BIN -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install -v --isolated --upgrade pip setuptools wheel --progress-bar on --retries 1 --timeout 15 --index-url https://mirrors.aliyun.com/pypi/simple/
pip install -v --isolated cmake>=3.26.1 --no-deps --progress-bar on --retries 1 --timeout 15 --index-url https://mirrors.aliyun.com/pypi/simple/

info "Installing Python dependencies (this takes a few minutes)..."
pip install -v --isolated -r "$SCRIPT_DIR/env/requirements.lock" \
    --index-url https://download.pytorch.org/whl/cpu \
    --extra-index-url https://mirrors.aliyun.com/pypi/simple/ \
    --progress-bar on --retries 1 --timeout 15

pass "Python dependencies installed"

################################################################################
# vLLM
################################################################################

info "Setting up vLLM..."

if [[ ! -d "$VLLM_SRC" ]]; then
    CLONE_ARGS="--depth 1"
    if [[ -n "$VLLM_REF" ]]; then
        CLONE_ARGS="--branch $VLLM_REF --depth 1"
    fi
    info "Cloning vLLM source..."
    if ! git clone $CLONE_ARGS "${GITHUB_PROXY}https://github.com/vllm-project/vllm.git" "$VLLM_SRC" 2>/dev/null; then
        git clone $CLONE_ARGS https://github.com/vllm-project/vllm.git "$VLLM_SRC"
    fi
fi

if ! python -c "import vllm" 2>/dev/null; then
    info "Building vLLM (CPU only, ~10-15 minutes)..."
    export VLLM_VERSION_OVERRIDE=0.1.0
    export CC="$CC_BIN"
    export CXX="$CXX_BIN"
    export VLLM_TARGET_DEVICE=cpu
    export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
    export MAX_JOBS=$(nproc)
    if [[ -d "$VLLM_SRC/.deps/onednn-src" ]]; then
        export FETCHCONTENT_SOURCE_DIR_ONEDNN="$VLLM_SRC/.deps/onednn-src"
        info "Using pre-downloaded oneDNN: $VLLM_SRC/.deps/onednn-src"
    fi
    pip install -v --isolated -e "$VLLM_SRC" --no-build-isolation --no-deps \
        --index-url https://download.pytorch.org/whl/cpu \
        --extra-index-url https://mirrors.aliyun.com/pypi/simple/ \
        --progress-bar on --retries 1 --timeout 15
    pass "vLLM installed: $(python -c 'import vllm; print(vllm.__version__)')"
else
    pass "vLLM already installed: $(python -c 'import vllm; print(vllm.__version__)')"
fi

################################################################################
# opencode
################################################################################

info "Installing opencode..."

if test -x "$HOME/.local/bin/opencode"; then
    pass "opencode already installed: $($HOME/.local/bin/opencode --version)"
else
    OPENCODE_DIR="$HOME/.local/bin"
    OPENCODE_CFG="$HOME/.config/opencode"
    mkdir -p "$OPENCODE_DIR" "$OPENCODE_CFG"

    FOUND=false

    # 1) Prefer bundled binary
    if [[ -f "$SCRIPT_DIR/bundle/opencode" ]]; then
        cp "$SCRIPT_DIR/bundle/opencode" "$OPENCODE_DIR/opencode"
        chmod +x "$OPENCODE_DIR/opencode"
        if [[ -d "$SCRIPT_DIR/bundle/skills" ]]; then
            cp -r "$SCRIPT_DIR/bundle/skills" "$OPENCODE_CFG/skills"
        fi
        if [[ -f "$SCRIPT_DIR/bundle/opencode.jsonc" ]]; then
            cp "$SCRIPT_DIR/bundle/opencode.jsonc" "$OPENCODE_CFG/opencode.jsonc"
        fi
        FOUND=true
        pass "opencode installed from bundle"
    fi

    # 2) Fallback: download from GitHub Releases
    if ! $FOUND; then
        OPENCODE_VER="1.18.4"
        for url in \
            "${GITHUB_PROXY}https://github.com/opencode-ai/opencode/releases/download/v${OPENCODE_VER}/opencode-linux-amd64" \
            "${GITHUB_PROXY}https://github.com/opencode-ai/opencode/releases/download/v${OPENCODE_VER}/opencode-linux-x64" \
            "https://github.com/opencode-ai/opencode/releases/download/v${OPENCODE_VER}/opencode-linux-amd64" \
            "https://github.com/opencode-ai/opencode/releases/download/v${OPENCODE_VER}/opencode-linux-x64"; do
            if curl -fSL --retry 2 -o "$OPENCODE_DIR/opencode" "$url" 2>/dev/null; then
                chmod +x "$OPENCODE_DIR/opencode"
                FOUND=true
                pass "opencode downloaded from GitHub Releases"
                break
            fi
        done
    fi

    if ! $FOUND; then
        warn "opencode not available (no bundle, no network), skipping"
    fi
fi

################################################################################
# Environment Config
################################################################################

info "Setting up environment config..."

CONFIG_DIR="$HOME/.config/cpu-vllm-infra"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/torch.env" <<'EOF'
# PyTorch CPU runtime tuning
OMP_NUM_THREADS=16
OMP_PROC_BIND=spread
OMP_PLACES=threads
OMP_DYNAMIC=FALSE
MKL_NUM_THREADS=16
MKL_DYNAMIC=FALSE
KMP_AFFINITY=granularity=fine,compact,1,0
KMP_BLOCKTIME=0
OPENBLAS_NUM_THREADS=1
PYTORCH_ALLOC_CONF=expandable_segments:True
EOF

cat > "$CONFIG_DIR/vllm.env" <<'EOF'
# vLLM CPU serving
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4:$(python -c 'import intel_openmp; print(intel_openmp.__file__.replace("__init__.py","../lib/libiomp5.so"))' 2>/dev/null || echo "")
  VLLM_CPU_KVCACHE_SPACE=4
VLLM_CPU_OMP_THREADS_BIND=0
VLLM_TARGET_DEVICE=cpu
EOF

cat > "$CONFIG_DIR/docker.env" <<EOF
WORKSPACE=$HOME/workspace
PATH=$VENV_DIR/bin:$HOME/.local/bin:\$PATH
EOF

pass "Config written to $CONFIG_DIR"

################################################################################
# Shell Integration
################################################################################

info "Setting up shell integration..."

ZSHRC="$HOME/.zshrc"
BASH_PROFILE="$HOME/.bashrc"

SHELL_SNIPPET='
# >>> vllm-infra >>>
export PATH="'"$VENV_DIR"'/bin:'"$HOME"'/.local/bin:$PATH"
source "'"$VENV_DIR"'/bin/activate" 2>/dev/null
export VLLM_TARGET_DEVICE=cpu
alias serve="bash '"$CONFIG_DIR"'/scripts/serve.sh"
alias bench="bash '"$CONFIG_DIR"'/scripts/bench.sh"
alias verify="bash '"$CONFIG_DIR"'/scripts/verify.sh"
alias snapshot="bash '"$CONFIG_DIR"'/scripts/snapshot.sh"
# <<< vllm-infra <<<
'

for rc in "$ZSHRC" "$BASH_PROFILE"; do
    if [[ -f "$rc" ]]; then
        if ! grep -q "vllm-infra" "$rc" 2>/dev/null; then
            echo "$SHELL_SNIPPET" >> "$rc"
        fi
    fi
done

################################################################################
# Scripts
################################################################################

info "Installing utility scripts..."

SCRIPTS_DIR="$CONFIG_DIR/scripts"
mkdir -p "$SCRIPTS_DIR"

for script in verify healthcheck snapshot serve bench; do
    if [[ -f "$SCRIPT_DIR/scripts/${script}.sh" ]]; then
        cp "$SCRIPT_DIR/scripts/${script}.sh" "$SCRIPTS_DIR/${script}.sh"
        chmod +x "$SCRIPTS_DIR/${script}.sh"
    fi
done

mkdir -p "$HOME/.local/bin"
for script in verify healthcheck snapshot serve bench; do
    ln -sf "$SCRIPTS_DIR/${script}.sh" "$HOME/.local/bin/vllm-${script}" 2>/dev/null || true
done

pass "Scripts installed to $SCRIPTS_DIR"

################################################################################
# Done
################################################################################

echo
echo -e "${BOLD}========================================================${RESET}"
echo -e "${GREEN} Installation complete!${RESET}"
echo -e "${BOLD}========================================================${RESET}"
echo
echo "What's installed:"
echo "  Python:       $(python --version 2>&1)"
echo "  torch:        $(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'N/A')"
echo "  vLLM:         $(python -c 'import vllm; print(vllm.__version__)' 2>/dev/null || echo 'pending')"
echo "  gcc:          $(gcc --version 2>/dev/null | head -1 || echo 'N/A')"
echo "  opencode:     $(test -x "$HOME/.local/bin/opencode" && "$HOME/.local/bin/opencode" --version || echo 'not installed')"
echo
echo "Quick start:"
echo "  source ~/.zshrc          # load environment"
echo "  serve                    # start vLLM API server"
echo "  verify                   # verify installation"
echo
