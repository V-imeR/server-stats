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

# ------------------------------------------------------------ ШАГ 2: память

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
      # на ядрах старше 3.14 поля MemAvailable нет — считаем приблизительно
      if (av == "") av = fr + buf + cac
      printf "%d %d %d %d %d\n",
             tot/1024, (tot-av)/1024, fr/1024, (buf+cac+sre-shm)/1024, av/1024
    }' /proc/meminfo
}

read -r m_total m_used m_free m_cache m_avail <<<"$(read_mem)"
m_pct=$(awk -v u="$m_used" -v t="$m_total" 'BEGIN { printf "%.1f", u * 100 / t }')

echo
echo "=== Память ==="
echo "Всего:       ${m_total} MiB"
echo "Занято:      ${m_used} MiB  (${m_pct}%)   = Всего - Доступно"
echo "Свободно:    ${m_free} MiB"
echo "Буферы/кеш:  ${m_cache} MiB"
echo "Доступно:    ${m_avail} MiB   <- на это можно рассчитывать"

# ------------------------------------------------------------ ШАГ 3: диск

read_disk() {
  df -Pk 2>/dev/null | awk '
    function hum(kb,   b, i, u) {
      split("B kB MB GB TB PB", u, " ")
      b = kb * 1024
      i = 1
      while (b >= 1024 && i < 6) { b /= 1024; i++ }
      return sprintf("%.1f %s", b, u[i])
    }
    NR == 1 { next }      # заголовок df пропускаем
    $1 ~ /^(tmpfs|devtmpfs|udev|overlay|squashfs|none|shm|efivarfs)$/ { next }
    {
      tot += $2; used += $3; avail += $4
      printf "%-22s %10s %10s %10s %7s  %s\n",
             $1, hum($2), hum($3), hum($4), $5, $6
    }
    END {
      printf "%-22s %10s %10s %10s %7.1f%%\n",
             "ИТОГО", hum(tot), hum(used), hum(avail), used * 100 / tot
    }'
}

echo
echo "=== Диск ==="
read_disk

# ------------------------------------------------------------ ШАГ 4: топ-5 по CPU

echo
echo "=== Топ-5 процессов по CPU ==="
ps -eo pid,user,%cpu,%mem,etime,comm --sort=-%cpu | head -6
printf 'Внимание: %%CPU у ps — среднее за время жизни процесса (см. ELAPSED).\n'

# ------------------------------------------------------------ ШАГ 5: топ-5 по памяти

echo
echo "=== Топ-5 процессов по памяти ==="
ps -eo pid,user,%mem,rss,comm --sort=-%mem | head -6
printf 'RSS — резидентная память, КиБ. Итог по памяти смотрите в разделе выше.\n'