#!/bin/bash

#!/bin/bash

# ------------------------------------------------------------ ШАГ 1: CPU

read_cpu() {
  awk '/^cpu / {
    total = 0
    for (i = 2; i <= 9; i++) total += $i
    print total, $5 + $6
  }' /proc/stat
}

read -r t1 idle1 <<<"$(read_cpu)"
sleep 5
read -r t2 idle2 <<<"$(read_cpu)"

dt=$(( t2 - t1 ))
di=$(( idle2 - idle1 ))

if [ "$dt" -gt 0 ]; then
  cpu_usage=$(awk -v t="$dt" -v i="$di" 'BEGIN { printf "%.1f", (t - i) * 100 / t }')
else
  cpu_usage="0.0"
fi

read -r la1 la5 la15 _ < /proc/loadavg
cores=$(nproc)

echo "=== CPU ==="
echo "Использование CPU: ${cpu_usage}%   (измерено за 1 с)"
echo "Load average:      $la1  $la5  $la15   (1 / 5 / 15 мин)"
echo "Ядер:              $cores"

