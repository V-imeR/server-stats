# Server Stats

A small Bash script that prints a quick snapshot of a Linux server's health:
CPU load, memory usage, disk usage, and the top 5 processes by CPU and memory.

No dependencies beyond the standard tools — every metric is read from `/proc`
or from `ps` / `df`, which are present on any Linux system.

## What it shows

| # | Section | Metrics |
|---|---------|---------|
| 1 | CPU | usage % over a 5-second interval, load average (1 / 5 / 15 min), core count |
| 2 | Memory | total, used (+ %), free, buffers/cache, available |
| 3 | Disk | per-filesystem and total size / used / free, weighted usage % |
| 4 | Top processes | top 5 processes by CPU |
| 5 | Top processes | top 5 processes by memory |

## Files

| File | Description |
|------|-------------|
| `server-stats_en.sh` | English comments and output |
| `server-stats_ru.sh` | Russian comments and output |

The two scripts are functionally identical — only the comments and the
printed text differ. The logic, commands and metric calculations are the same.

## Requirements

- Linux — the script reads `/proc/stat`, `/proc/meminfo`, `/proc/loadavg`
- `bash` — the script uses `<<<` (here-string) and `read -r`, which are bash
  features and are not available in POSIX `sh` / `dash`. The shebang is
  `#!/bin/bash` for this reason; on Debian/Ubuntu run it with `./script.sh`
  or `bash script.sh`, never `sh script.sh`
- `awk`, `ps`, `df`, `nproc` — part of base coreutils / procps

## Usage

```bash
chmod +x server-stats_en.sh
./server-stats_en.sh
```

The script takes **at least 5 seconds** to run. It samples the CPU counters,
waits 5 seconds, samples again, and computes the difference between the two.
A single snapshot of `/proc/stat` would only give counters since boot, which
says nothing about current load.

For a quick look at what is currently happening, run it in a loop:

```bash
watch -n 10 ./server-stats_en.sh
```

## Sample output

```
=== CPU ===
CPU usage:         3.5%   (measured over 5 s)
Load average:      0.00  0.02  0.00   (1 / 5 / 15 min)
CPU cores:         2

=== Memory ===
Total:             1984 MiB
Used:              497 MiB  (25.1%)   = Total - Available
Free:              1269 MiB
Buffers/cache:     402 MiB
Available:         1487 MiB   <- this is what you can rely on

=== Disk ===
/dev/root                 24.1 GB     4.0 GB    19.8 GB     17%  /
TOTAL                     24.1 GB     4.0 GB    19.8 GB    16.7%

=== Top 5 processes by CPU ===
    PID USER     %CPU %MEM     ELAPSED COMMAND
    437 root     14.8  4.8       00:12 jupyter-server
    475 root     13.2  5.3       00:09 python3.13
    463 root      6.0  3.2       00:10 uvicorn
    490 root      3.8  3.9       00:09 node
    359 root      1.7  1.1       00:14 envd
Note: %CPU in ps is an average over the process lifetime (see ELAPSED).

=== Top 5 processes by memory ===
    PID USER     %MEM   RSS COMMAND
    475 root      5.3 109468 python3.13
    437 root      4.8  98260 jupyter-server
    490 root      3.9  79392 node
    463 root      3.2  66728 uvicorn
    504 root      1.9  39900 node
RSS is resident memory in KiB. For the total, see the Memory section above.
```

## How the numbers are computed

Each metric needed a different approach, and a few of the obvious solutions
are wrong:

**CPU** — `/proc/stat` holds counters accumulated since boot, so absolute
values are meaningless. The script takes two samples 5 seconds apart and
computes `(total - idle) / total * 100` over the delta. Idle is `idle + iowait`,
not just `idle`: a core waiting on disk is not doing useful work.

**Memory** — `used` is `MemTotal - MemAvailable`, **not** `MemTotal - MemFree`.
Most free memory is held as disk cache and is released on demand, so
`MemFree` alone makes a healthy server look nearly full. `MemAvailable` is
the kernel's own estimate of what can actually be handed out. On kernels
older than 3.14 the field is absent and the script falls back to
`MemFree + Buffers + Cached`.

**Disk** — pseudo-filesystems (`tmpfs`, `overlay`, `devtmpfs`, ...) live in
RAM, not on disk, and are filtered out — otherwise the "total disk size"
would include gigabytes of memory. The total percentage is
`sum(used) / sum(total)`, not the average of per-filesystem percentages:
averaging would report 50% for a full 100 GB disk next to an empty 1000 GB one.

**Processes** — `ps --sort` handles ordering. Note that `%CPU` in `ps` is
`CPU_TIME / ELAPSED_TIME`, an average over the whole process lifetime, so a
process that ran hot and then went idle keeps a high value for a long time.
The `ELAPSED` column is included so this is visible.

## Known limitations

- **Linux only.** BSD/macOS have no `/proc`, so `ps` and `df` parts would run
  but CPU and memory sections would not.
- **`ps --sort`** requires `procps` or busybox `ps`. On very old or minimal
  systems, replace it with `ps ... --no-headers | sort -k3 -rn`.
- **`rss` cannot be summed.** Shared pages (libraries, forked processes) are
  counted in every process that maps them, so the sum of `rss` exceeds the
  real memory in use. Use the Memory section for totals; `rss` is only for
  comparing processes against each other.
- **`vsz` is deliberately not shown.** Virtual size is reserved address space,
  which for Java, PostgreSQL and others can be many times the physical RAM.

## License

MIT
