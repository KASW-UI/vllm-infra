#!/usr/bin/env bash

###############################################################################
# vLLM CPU API Server Launcher
###############################################################################

set -Eeuo pipefail

GREEN="\033[32m"
BLUE="\033[34m"
RESET="\033[0m"

MODEL="${MODEL:-Qwen/Qwen2.5-1.5B-Instruct}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"

echo -e "${BLUE}========================================================${RESET}"
echo -e "${BLUE} vLLM CPU API Server${RESET}"
echo -e "${BLUE}========================================================${RESET}"
echo
echo -e "  Model:           ${GREEN}${MODEL}${RESET}"
echo -e "  Host:            ${GREEN}${HOST}${RESET}"
echo -e "  Port:            ${GREEN}${PORT}${RESET}"
echo -e "  Max model len:   ${GREEN}${MAX_MODEL_LEN}${RESET}"
echo
echo -e "${BLUE}========================================================${RESET}"
echo

exec python -m vllm.entrypoints.openai.api_server \
    --model "${MODEL}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    "$@"
