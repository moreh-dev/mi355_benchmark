#!/usr/bin/env bash

# === Required Env Vars ===
PORT=8888
SERVER_LOG=./logs/server.log

MODEL=LGAI-EXAONE/EXAONE-3.5-32B-Instruct
TP=1

set -x
export VLLM_SERVER_DEV_MODE=1
export VLLM_ROCM_USE_AITER=1
export VLLM_ROCM_USE_AITER_MHA=0

vllm serve $MODEL \
    --host localhost \
    --port $PORT \
    --tensor-parallel-size $TP \
    --trust-remote-code \
    --no-enable-prefix-caching > $SERVER_LOG 2>&1 &
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

ISL_LIST=("512" "4096" "16384")
OSL_LIST=("512" "1024" "1024")
CONC_LIST=("1" "8" "64" "256")

for idx in "${!ISL_LIST[@]}"; do
  ISL="${ISL_LIST[$idx]}"
  OSL="${OSL_LIST[$idx]}"

  for CONC in "${CONC_LIST[@]}"; do

    # reset prefix cache
    STATUS_CODE=$(curl -X POST -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/reset_prefix_cache -H "Content-Type: application/json")
    if [ "$STATUS_CODE" -eq 200 ]; then
      echo "Prefix cache reset successfully."
    elif [ "$STATUS_CODE" -eq 404 ]; then
        echo "Warning: The /reset_prefix_cache endpoint was not found, which will lead to incorrect benchmark results. To enable this endpoint, start the server with the environment variable VLLM_SERVER_DEV_MODE=1 before running the benchmark."
    else
        echo "Warning: Prefix cache reset failed with status code: $STATUS_CODE."
    fi

    RESULT_FILENAME="exoane_3.5_32B_${ISL}_${OSL}_${CONC}"
    NUM_PROMPTS=$(( CONC * 3 ))
    run_benchmark_serving \
        --model "$MODEL" \
        --port "$PORT" \
        --backend vllm \
        --input-len "$ISL" \
        --output-len "$OSL" \
        --num-prompts "$NUM_PROMPTS" \
        --max-concurrency "$CONC" \
        --result-filename "$RESULT_FILENAME" \
        --result-dir /workspace/logs 2>&1 | tee "logs/${RESULT_FILENAME}.log"
      
      sleep 20

  done
done