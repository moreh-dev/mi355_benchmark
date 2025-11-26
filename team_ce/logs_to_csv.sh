#!/bin/bash

# How to: .logs_to_csvs.sh /path/to/log_folder output.csv
LOG_DIR="$1"
OUTPUT_CSV="$2"

echo "Filename,Duration,QPS,Output_TPS,Mean_TTFT,Mean_TPOT" > "$OUTPUT_CSV"
for file in $(ls "$LOG_DIR"/*.log | sort -V); do
    [ -e "$file" ] || continue

    duration=$(grep "Benchmark duration (s):" "$file" | awk '{print $4}')
    qps=$(grep "Request throughput (req/s):" "$file" | awk '{print $4}')
    output_tps=$(grep "Output token throughput (tok/s):" "$file" | awk '{print $5}')
    mean_ttft=$(grep "Mean TTFT (ms):" "$file" | awk '{print $4}')
    mean_tpot=$(grep "Mean TPOT (ms):" "$file" | sed -E 's/.*: *([0-9.]+).*/\1/')

    echo "$(basename "$file"),$duration,$qps,$output_tps,$mean_ttft,$mean_tpot" >> "$OUTPUT_CSV"
done

echo "CSV export completed: $OUTPUT_CSV"
