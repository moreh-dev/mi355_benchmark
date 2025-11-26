#!/usr/bin/env bash

# === Workflow-defined Env Vars ===
IMAGE=moreh-vllm:gpt_oss_rocm7.0.0_v0.11.1.1124_gfx950
# Reference: rocm/7.0:rocm7.0_ubuntu_22.04_vllm_0.10.1_instinct_20250927_rc1
# rocm_base: rocm/vllm:rocm7.0.0_vllm_0.11.1_20251103
# sgl: rocm/7.0:rocm7.0_ubuntu_22.04_sgl-dev-v0.5.2-rocm7.0-mi35x-20250915
# moreh: moreh-vllm:gpt_oss_rocm7.0.0_v0.11.1.1124_gfx950
HF_HUB_CACHE_MOUNT=~/.cache/huggingface
HF_HUB_CACHE=/root/.cache/huggingface
PORT=8888

server_name="ce-bmk-dsr1-server"

set -x
docker run --rm --ipc=host --shm-size=16g --network=host --name=$server_name \
--privileged --cap-add=CAP_SYS_ADMIN --device=/dev/kfd --device=/dev/dri --device=/dev/mem \
--cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
-v $HF_HUB_CACHE_MOUNT:$HF_HUB_CACHE \
-v ~/mi355_benchmark/team_ce/dsr1:/workspace/ -w /workspace/ -e PORT=$PORT \
--entrypoint=/bin/bash \
$IMAGE dsr1_fp8_mi355x_docker.sh

if ls gpucore.* 1> /dev/null 2>&1; then
  echo "gpucore files exist. not good"
  rm -f gpucore.*
fi
