#!/usr/bin/env bash

# === Required Env Vars ===
PORT=8888
# MODEL=deepseek-ai/DeepSeek-R1-0528
MODEL=/app/deepseek-r1-0528

SERVER_LOG=logs/server.log

# reference: https://rocm.docs.amd.com/en/docs-7.0-docker/benchmark-docker/inference-vllm-deepseek-r1-fp8.html
model=deepseek-ai/DeepSeek-R1-0528
max_model_len=16384           # Must be >= the input + the output lengths.
max_seq_len_to_capture=10240  # Beneficial to set this to max_model_len.
max_num_seqs=1024
max_num_batched_tokens=65536 # Smaller values may result in better TTFT but worse TPOT / throughput.
tensor_parallel_size=8

export VLLM_SERVER_DEV_MODE=1
export VLLM_ROCM_USE_AITER=1
export VLLM_USE_AITER_UNIFIED_ATTENTION=1
export VLLM_ROCM_USE_AITER_MHA=0
export VLLM_SERVER_DEV_MODE=1

set -x
vllm serve ${model} \
    --host localhost \
    --port $PORT \
    --swap-space 64 \
    --tensor-parallel-size ${tensor_parallel_size} \
    --max-num-seqs ${max_num_seqs} \
    --no-enable-prefix-caching \
    --max-num-batched-tokens ${max_num_batched_tokens} \
    --max-model-len ${max_model_len} \
    --block-size 1 \
    --gpu-memory-utilization 0.95 \
    --async-scheduling > $SERVER_LOG 2>&1 &
set +x

# for sglang (optional)
# python3 -m sglang.launch_server \
#     --model-path $MODEL \
#     --host=0.0.0.0 \
#     --port $PORT \ 
#     --tensor-parallel-size $TP \
#     --trust-remote-code \
#     --chunked-prefill-size 196608 \
#     --mem-fraction-static 0.8 --disable-radix-cache \
#     --num-continuous-decode-steps 4 \
#     --max-prefill-tokens 196608 \
#     --cuda-graph-max-bs 128 > $SERVER_LOG 2>&1 &

SERVER_PID=$!

# Source benchmark utilities
source "benchmark_lib.sh"

# Wait for server to be ready
wait_for_server_ready --port "$PORT" --server-log "$SERVER_LOG" --server-pid "$SERVER_PID"

ISL_LIST=("1024" "8192")
OSL_LIST=("1024" "1024")
CONC_LIST=("4" "8" "16" "32")

for idx in "${!ISL_LIST[@]}"; do
  ISL="${ISL_LIST[$idx]}"
  OSL="${OSL_LIST[$idx]}"

  for CONC in "${CONC_LIST[@]}"; do

    # reset prefix cache
    STATUS_CODE=$(curl -X POST -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/flush_cache -H "Content-Type: application/json")
    if [ "$STATUS_CODE" -eq 200 ]; then
      echo "Prefix cache reset successfully."
    elif [ "$STATUS_CODE" -eq 404 ]; then
        echo "Warning: The /reset_prefix_cache endpoint was not found, which will lead to incorrect benchmark results. To enable this endpoint, start the server with the environment variable VLLM_SERVER_DEV_MODE=1 before running the benchmark."
    else
        echo "Warning: Prefix cache reset failed with status code: $STATUS_CODE."
    fi

    RESULT_FILENAME="dsr1_0528_fp8_${ISL}_${OSL}_${CONC}.log"
    NUM_PROMPTS=$(( CONC * 10 ))
    run_benchmark_serving \
        --model "$MODEL" \
        --port "$PORT" \
        --backend vllm \
        --input-len "$ISL" \
        --output-len "$OSL" \
        --num-prompts "$NUM_PROMPTS" \
        --max-concurrency "$CONC" \
        --result-filename "$RESULT_FILENAME" \
        --result-dir /workspace/
      
      sleep 20

  done
done