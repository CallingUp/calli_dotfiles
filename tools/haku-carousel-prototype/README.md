# Experimental Rust / Iced carousel

This directory contains experimental alternatives to the active QML carousel.
They are not built or enabled by the portable installer. Rust is not assumed
to use less memory or CPU than QML.

## Builds

From the repository root:

```sh
cargo build --release --locked --manifest-path tools/haku-carousel-prototype/Cargo.toml
cargo build --release --locked --manifest-path tools/haku-carousel-prototype/Cargo.toml --no-default-features --features gpu
```

The complete layer-shell implementation and its build options are documented
in [README-FULL.md](README-FULL.md). Keep QML as the normal backend unless you
explicitly want to test the experimental implementation.

## Measurements

The scripts in this directory can compare navigation, idle and total resident
memory. They open windows and may move carousel selection; read each script
before executing it. Do not infer power or temperature savings from a short
CPU/RAM sample.

Use a stable workload, verify actual window visibility and count the shared
QuickShell process together with the frontend and its workers. Report PSS and
SwapPss separately rather than summing duplicated RSS.

