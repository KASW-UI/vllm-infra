#!/usr/bin/env bash
set -Eeuo pipefail

SNAPSHOT_DIR="${SNAPSHOT_DIR:-/workspace/snapshots}"
LOG_DIR="${LOG_DIR:-/workspace/logs}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")

mkdir -p "$SNAPSHOT_DIR" "$LOG_DIR"

OS_ID=$(cat /etc/os-release 2>/dev/null | grep '^ID=' | cut -d= -f2 | tr -d '"' || echo "unknown")
OS_VERSION=$(cat /etc/os-release 2>/dev/null | grep '^VERSION_ID=' | cut -d= -f2 | tr -d '"' || echo "unknown")
KERNEL=$(uname -r)
ARCH=$(uname -m)
CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d':' -f2 | xargs || echo "unknown")
CPU_CORES=$(nproc)
PYTHON_V=$(python --version 2>&1 || echo "unknown")
TORCH_V=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
VLLM_V=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo "unknown")
TF_V=$(python -c "import transformers; print(transformers.__version__)" 2>/dev/null || echo "unknown")

apt-mark showmanual 2>/dev/null > "$LOG_DIR/apt-installed.txt" || true
echo "---" >> "$LOG_DIR/apt-installed.txt" 2>/dev/null || true
dpkg-query -W -f='${binary:Package} ${Version}\n' 2>/dev/null >> "$LOG_DIR/apt-installed.txt" || true

python -m pip freeze 2>/dev/null > "$LOG_DIR/pip-freeze.txt" || true

cat > "$SNAPSHOT_DIR/deployment.json" <<JSONEOF
{
  "project": "cpu-vllm-infra",
  "time": "${TIMESTAMP}",
  "hostname": "${HOSTNAME}",
  "image": "${IMAGE_NAME:-cpu-vllm-infra:ubuntu22.04-torch2.11.0}",
  "os": "${OS_ID} ${OS_VERSION}",
  "kernel": "${KERNEL}",
  "architecture": "${ARCH}",
  "cpu_model": "${CPU_MODEL}",
  "cpu_cores": ${CPU_CORES},
  "python": "${PYTHON_V}",
  "torch": "${TORCH_V}",
  "vllm": "${VLLM_V}",
  "transformers": "${TF_V}"
}
JSONEOF

cat > "$SNAPSHOT_DIR/deployment.yaml" <<YMLEOF
project: cpu-vllm-infra
time: "${TIMESTAMP}"
hostname: "${HOSTNAME}"
image: "${IMAGE_NAME:-cpu-vllm-infra:ubuntu22.04-torch2.11.0}"
os: "${OS_ID} ${OS_VERSION}"
kernel: "${KERNEL}"
architecture: "${ARCH}"
cpu_model: "${CPU_MODEL}"
cpu_cores: ${CPU_CORES}
python: "${PYTHON_V}"
torch: "${TORCH_V}"
vllm: "${VLLM_V}"
transformers: "${TF_V}"
YMLEOF

echo "Snapshot saved:"
echo "  $SNAPSHOT_DIR/deployment.json"
echo "  $SNAPSHOT_DIR/deployment.yaml"
echo "  $LOG_DIR/apt-installed.txt"
echo "  $LOG_DIR/pip-freeze.txt"
