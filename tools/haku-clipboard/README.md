# Clipboard worker Rust

Helper bajo demanda: no daemon, sin cambios a la UI ni al almacén de cliphist.
El launcher sigue en Python; las operaciones de la UI usan
`scripts/bin/haku-clipboard-worker`, que ejecuta Rust si está compilado y conserva
Python como alternativa. Sesión, lista, clasificación, preview, copiar, borrar,
vaciar y limpieza mantienen el protocolo JSON existente.

```sh
cargo build --locked --release --manifest-path ~/haku_shell/tools/haku-clipboard/Cargo.toml
cargo test --locked --manifest-path ~/haku_shell/tools/haku-clipboard/Cargo.toml
python3 ~/haku_shell/tools/haku-clipboard/test_worker.py
```

Las pruebas de integración sustituyen cliphist y wl-copy por herramientas falsas:
no modifican el historial ni el clipboard real. Comprueban límites de 16 MiB para
preview, copia original sin ese límite, Unicode, IDs estrictos, stdin literal,
permisos 0700/0600, reemplazo seguro de destinos y limpieza restringida.

Medición local de `list`, 15 ejecuciones, stdout descartado: mediana Python
54,36 ms frente a Rust 3,31 ms, incluyendo cliphist y lanzamiento del proceso.
No es una medición de ahorro global de RAM/temperatura. Las operaciones son
efímeras; el coste de cliphist, decodificación de imágenes y la UI permanece.
