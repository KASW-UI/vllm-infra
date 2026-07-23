#!/usr/bin/env bash
set -euo pipefail

source /workspace/.venv/bin/activate 2>/dev/null || true

source /home/dev/.config/cpu-vllm-infra/torch.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/vllm.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/docker.env 2>/dev/null || true

if [[ -f /workspace/vllm/setup.py || -f /workspace/vllm/pyproject.toml ]]; then
    if ! python -c "import vllm" 2>/dev/null; then
        echo "[entrypoint] Installing vLLM as editable..."
        VLLM_TARGET_DEVICE=cpu pip install -e /workspace/vllm --no-build-isolation \
            --index-url https://download.pytorch.org/whl/cpu \
            --extra-index-url https://mirrors.aliyun.com/pypi/simple/
        echo "[entrypoint] vLLM installed."
    fi
fi

exec "$@"
