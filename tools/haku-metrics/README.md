# Native Haku metrics

Small, dependency-free Rust sampler for the five fields consumed by SystemStats:
CPU usage, used RAM, RAM percentage, CPU temperature and uptime. Reads /proc and
CPU hwmon/thermal files directly; no /proc process enumeration, GPU wakeups,
nvidia-smi, sensors command, disk queries, shell subprocesses or network access.

The QML service starts it only while a stats consumer is open, then stops it.
Interval defaults to 4 seconds and is clamped to 1–60 seconds. CPU uses deltas
of the first eight /proc/stat counters, excluding duplicate guest time. Memory
uses MemAvailable. Missing sensors produce --°C, not a fake zero temperature.

Build and test (one compiler job, no downloads):

```sh
cargo test --offline --manifest-path ~/haku_shell/tools/haku-metrics/Cargo.toml -j 1
cargo build --release --offline --manifest-path ~/haku_shell/tools/haku-metrics/Cargo.toml -j 1
~/haku_shell/tools/haku-metrics/target/release/haku-metrics --once
python3 ~/haku_shell/tools/haku-metrics/benchmark.py
```

The QML launcher falls back to the original Python helper on fresh clones without
a compiled binary. It does not replace Python's full process-list API used by
other legacy components. No binary/build directory is tracked in Git.

Resource usage depends on the system.

Related UI changes bound album cover decoding to display resolution, disable
unneeded cover mipmaps, and stop hidden typewriter/idle-icon/clock animations.
Visible animations, panels and playback controls remain available.
