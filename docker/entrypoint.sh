#!/usr/bin/env bash
set -euo pipefail

source /workspace/.venv/bin/activate 2>/dev/null || true

source /home/dev/.config/cpu-vllm-infra/torch.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/vllm.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/docker.env 2>/dev/null || true

exec "$@"
