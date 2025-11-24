#!/usr/bin/env bash

# === Workflow-defined Env Vars ===
IMAGE=rocm/vllm:rocm7.0.0_vllm_0.11.1_20251103
# rocm_base: rocm/vllm:rocm7.0.0_vllm_0.11.1_20251103
# sgl: rocm/sgl-dev:v0.5.5.post3-rocm700-mi35x-20251119
# moreh: 
HF_HUB_CACHE_MOUNT=~/.cache/huggingface
HF_HUB_CACHE=/root/.cache/huggingface
PORT=8888

server_name="ce-bmk-exaone-server"

set -x
docker run --rm --ipc=host --shm-size=16g --network=host --name=$server_name \
--privileged --cap-add=CAP_SYS_ADMIN --device=/dev/kfd --device=/dev/dri --device=/dev/mem \
--cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
-v $HF_HUB_CACHE_MOUNT:$HF_HUB_CACHE \
-v ~/mi355_benchmark/team_ce/exaone:/workspace/ -w /workspace/ -e PORT=$PORT \
--entrypoint=/bin/bash \
$IMAGE exaone_mi355x_docker.sh

if ls gpucore.* 1> /dev/null 2>&1; then
  echo "gpucore files exist. not good"
  rm -f gpucore.*
fi
