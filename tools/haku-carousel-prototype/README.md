# Experimental Rust / Iced carousel

[Documentación](../../docs/README.md) · [Instalación](../../docs/INSTALL.md)

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

## Scope

The test utilities may open windows and change carousel selection. Review each
script before running it. They are not part of the guided installation.

