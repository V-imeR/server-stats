#!/bin/bash

# ------------------------------------------------------------ STEP 1: CPU

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
echo "CPU usage:         ${cpu_usage}%   (measured over 5 s)"
echo "Load average:      $la1  $la5  $la15   (1 / 5 / 15 min)"
echo "CPU cores:         $cores"

# ------------------------------------------------------------ STEP 2: memory

read_mem() {
  awk '
    /^MemTotal:/     { tot = $2 }
    /^MemFree:/      { fr  = $2 }
    /^MemAvailable:/ { av  = $2 }
    /^Buffers:/      { buf = $2 }
    /^Cached:/       { cac = $2 }
    /^SReclaimable:/ { sre = $2 }
    /^Shmem:/        { shm = $2 }
    END {
      # kernels older than 3.14 have no MemAvailable field - estimate it
      if (av == "") av = fr + buf + cac
      printf "%d %d %d %d %d\n",
             tot/1024, (tot-av)/1024, fr/1024, (buf+cac+sre-shm)/1024, av/1024
    }' /proc/meminfo
}

read -r m_total m_used m_free m_cache m_avail <<<"$(read_mem)"
m_pct=$(awk -v u="$m_used" -v t="$m_total" 'BEGIN { printf "%.1f", u * 100 / t }')

echo
echo "=== Memory ==="
echo "Total:             ${m_total} MiB"
echo "Used:              ${m_used} MiB  (${m_pct}%)   = Total - Available"
echo "Free:              ${m_free} MiB"
echo "Buffers/cache:     ${m_cache} MiB"
echo "Available:         ${m_avail} MiB   <- this is what you can rely on"

# ------------------------------------------------------------ STEP 3: disk

read_disk() {
  df -Pk 2>/dev/null | awk '
    function hum(kb,   b, i, u) {
      split("B kB MB GB TB PB", u, " ")
      b = kb * 1024
      i = 1
      while (b >= 1024 && i < 6) { b /= 1024; i++ }
      return sprintf("%.1f %s", b, u[i])
    }
    NR == 1 { next }      # skip the df header line
    $1 ~ /^(tmpfs|devtmpfs|udev|overlay|squashfs|none|shm|efivarfs)$/ { next }
    {
      tot += $2; used += $3; avail += $4
      printf "%-22s %10s %10s %10s %7s  %s\n",
             $1, hum($2), hum($3), hum($4), $5, $6
    }
    END {
      printf "%-22s %10s %10s %10s %7.1f%%\n",
             "TOTAL", hum(tot), hum(used), hum(avail), used * 100 / tot
    }'
}

echo
echo "=== Disk ==="
read_disk

# ------------------------------------------------------------ STEP 4: top-5 by CPU

echo
echo "=== Top 5 processes by CPU ==="
ps -eo pid,user,%cpu,%mem,etime,comm --sort=-%cpu | head -6

# ------------------------------------------------------------ STEP 5: top-5 by memory

echo
echo "=== Top 5 processes by memory ==="
ps -eo pid,user,%mem,rss,comm --sort=-%mem | head -6

