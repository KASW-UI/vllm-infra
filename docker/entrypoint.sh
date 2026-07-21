#!/usr/bin/env bash
set -euo pipefail

source /workspace/.venv/bin/activate 2>/dev/null || true

source /home/dev/.config/cpu-vllm-infra/torch.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/vllm.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/docker.env 2>/dev/null || true

if [[ -d /workspace/vllm ]] && [[ -f /workspace/vllm/setup.py || -f /workspace/vllm/pyproject.toml ]]; then
    if ! python -c "import vllm" 2>/dev/null; then
        echo "[entrypoint] Installing vLLM as editable..."
        pip install --no-cache-dir -e /workspace/vllm --no-build-isolation
        echo "[entrypoint] vLLM installed."
    fi
fi

exec "$@"
