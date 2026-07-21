#!/usr/bin/env bash

###############################################################################
# vLLM CPU Benchmarking (benchmark_serving.py)
###############################################################################

set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
RESET="\033[0m"

MODEL="${MODEL:-Qwen/Qwen2.5-1.5B-Instruct}"
BACKEND="${BACKEND:-vllm}"
DATASET_NAME="${DATASET_NAME:-random}"
DATASET_PATH="${DATASET_PATH:-}"
NUM_PROMPTS="${NUM_PROMPTS:-100}"
REQUEST_RATE="${REQUEST_RATE:-inf}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8000}"

BENCH_SCRIPT="/workspace/vllm/benchmarks/benchmark_serving.py"

echo -e "${BLUE}========================================================${RESET}"
echo -e "${BLUE} vLLM CPU Benchmark${RESET}"
echo -e "${BLUE}========================================================${RESET}"
echo
echo -e "  Model:        ${GREEN}${MODEL}${RESET}"
echo -e "  Backend:      ${GREEN}${BACKEND}${RESET}"
echo -e "  Dataset:      ${GREEN}${DATASET_NAME}${RESET}"
echo -e "  Num prompts:  ${GREEN}${NUM_PROMPTS}${RESET}"
echo -e "  Request rate: ${GREEN}${REQUEST_RATE}${RESET}"
echo
echo -e "${BLUE}========================================================${RESET}"
echo

if [[ ! -f "$BENCH_SCRIPT" ]]; then
    echo "Error: benchmark_serving.py not found at $BENCH_SCRIPT"
    exit 1
fi

DATASET_ARGS="--dataset-name ${DATASET_NAME}"
if [[ -n "${DATASET_PATH}" ]]; then
    DATASET_ARGS="--dataset-path ${DATASET_PATH}"
fi

exec python "$BENCH_SCRIPT" \
    --backend "${BACKEND}" \
    --model "${MODEL}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --num-prompts "${NUM_PROMPTS}" \
    --request-rate "${REQUEST_RATE}" \
    ${DATASET_ARGS} \
    "$@"
