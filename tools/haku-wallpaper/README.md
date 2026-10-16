# Worker nativo del carrusel

[Documentación](../../docs/README.md) · [Instalación](../../docs/INSTALL.md)

Backend bajo demanda, sin daemon. Rust implementa el catálogo local,
búsqueda Wallhaven, validación de rutas y miniaturas locales/web; reutiliza los hashes SHA-256 existentes,
ImageMagick, geometría 420×300, caché atómica y límite de 20 segundos por conversión.
Aplicar (incluida la descarga del original) y Papelera también usan Rust.
La descarga original conserva el límite de 64 MiB y reemplazo atómico.
Aplicar y Papelera comparten `wallpaper_selector_apply.lock` mediante flock,
compatible con el backend anterior. Aplicar conserva `wallpaper_generation`,
`current_wallpaper`, las cuatro direcciones y los scripts `wallpaper-transition`
y `wallpaper-theme-sync` en sesiones independientes. Si el fondo ya está activo,
no regenera el estado ni lanza animación. La Papelera usa gio, nunca borrado directo,
y rechaza el fondo activo. El portable usa adaptadores de `installer/`: fade y estado del lock, sin
modificar SDDM ni desplegar el renderer avanzado.
El filtrado interactivo permanece en QML, sin procesos externos por pulsación.

El catálogo incluye `cachedThumbnail`: nombre SHA-256 del JPEG ya existente, o
`null` si falta/está vacío. Se calcula con la misma ruta canónica y mtime en
nanosegundos que la generación original; no reutiliza caché de una versión
anterior del archivo. Solo se envía el nombre para no repetir el directorio de
caché en cada fila. QML arma la URL local y evita lanzar un worker por cada hit.
Si desaparece el archivo mientras el carrusel está abierto, QML recurre una vez
al worker habitual. No se añade daemon ni caché global de originales.

`scripts/bin/haku-wallpaper-worker` elige Rust y usa Python si el binario falta.
El launcher normal también es Rust (`--launch`), a través de
`scripts/bin/wallpaper-carousel`. El atajo instalado delega en ese script del repo.
Una segunda pulsación cierra sin volver a listar la galería. Si no hay shell
principal, abre el renderer independiente con una petición temporal privada
(directorio 0700, archivo 0600), limpiada al salir o recibir SIGTERM/SIGINT.
Python se conserva como alternativa si falta el binario compilado.

HTTPS usa `curl` del sistema (sin configuración personal de curl), con tiempo
máximo de 20 s por petición, HTTPS obligatorio y límites de 4 MiB para respuestas
de búsqueda y 8 MiB para miniaturas. Cada redirección se valida antes de seguirla:
solo wallhaven.cc, w.wallhaven.cc y th.wallhaven.cc, sin credenciales ni puertos
alternativos. La URL con API key se entrega por stdin, no por argv ni logs.
Rust conserva favoritos, SFW, categorías 111, 1920×1080 y 16:9.

```sh
cargo build --locked --release --manifest-path ~/haku_shell/tools/haku-wallpaper/Cargo.toml
cargo test --locked --manifest-path ~/haku_shell/tools/haku-wallpaper/Cargo.toml
python3 ~/haku_shell/tools/haku-wallpaper/test_worker.py
python3 ~/haku_shell/config/quickshell/haku-wallpaper/test_backend.py
```

Las pruebas usan galerías temporales y acciones simuladas. No aplican ni borran
wallpapers reales. Verifican rutas, symlinks, caché compatible, comandos de
miniaturas y solicitudes por línea (sin esperar EOF del proceso QML).
