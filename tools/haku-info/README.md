# Información y atajos Rust

## Paleta de wallpaper

`haku-info theme IMAGE [true|false]` sustituye el generador Python para imágenes
estáticas, conservando las mismas operaciones ImageMagick y cálculos HSL
(incluidos truncado, empates y detección de grises). No añade un daemon.
Escribe los cuatro JSON bajo `~/.cache/quickshell` mediante renombrado atómico
por archivo, respetando el modo claro/oscuro y los temas manuales. Los cuatro
archivos no constituyen una transacción conjunta. Errores de extracción no
se convierten en una paleta inventada; las llamadas tienen límite de 30 s.

`scripts/bin/haku-theme-worker` selecciona Rust y mantiene el generador anterior
como respaldo si no hay binario. GIF/WebP conservan Python/GdkPixbuf para no
alterar sus fotogramas/JPEG intermedios. La aplicación de temas sigue en Python.
Esto solo afecta cambios de wallpaper con generación dinámica, no el reposo.

```sh
python3 -B ~/haku_shell/tools/haku-info/test_theme.py
```

Las pruebas comparan 200 histogramas aleatorios, grises/empates, una imagen
local y los cuatro archivos del generador completo. Se ejecutan con HOME
temporal: no modifican el tema activo.

Medianas de 7 ejecuciones completas con `icon.png` (720×720), HOME temporal:
Python 196 ms / Rust 152 ms (~22 % menos tiempo). Pico RSS reportado por
`wait4`, incluidos descendientes: 27,81 / 25,61 MiB (~2,2 MiB menos).
Es el pico de esta operación, no una suma de PSS ni ahorro de la shell en reposo.
Se conserva la ruta de caché del generador anterior (`quickshell`); no se
modifican aquí los otros lectores/escritores que usan `haku-minflair-niri`.

`haku-info packages QUERY` procesa la búsqueda de paquetes en Rust: conserva
campos JSON, orden por coincidencia/instalación/repositorio y límite de 50.
Invoca yay sin shell, con salida sin colores y límite de 15 s (2 s de gracia).
La UI usa el wrapper; `--list-installed`, `--list-updates` y `--featured`
permanecen en Python. No instala ni elimina paquetes ni añade un daemon.
Tres pruebas unitarias cubren ranking, campos, consultas literales, entradas
incompletas y límite. El coste de red/yay no desaparece y no implica ahorro
de RAM en reposo.

Helper bajo demanda, sin daemon. `haku-info shortcuts [path]` lee la configuración
Niri y sus includes sin ejecutar bindings. Conserva comentarios/secciones,
títulos, atajos ocultos y protección frente a includes duplicados/cíclicos.
`haku-info system` devuelve el contrato JSON estático usado por SystemStats.

`haku-info players` enumera reproductores instalados desde archivos desktop XDG
y los reproductores CLI conocidos. Conserva campos, orden, filtros de utilidades,
deduplicación y precedencia del auxiliar anterior. No ejecuta las aplicaciones.
Se invoca al iniciar MprisService, no periódicamente. Las sesiones activas y los
controles MPRIS continúan en Quickshell, sin cambios ni daemon adicional.
La lista real coincide exactamente con Python. Las pruebas incluyen archivos
desktop ocultos, duplicados, valores DEFAULT, utilidades excluidas y CLI.

La UI llama `scripts/bin/haku-info-worker`. Si falta el binario compilado,
el wrapper usa los auxiliares Python anteriores. No se eliminan esos archivos.

```sh
cargo build --locked --release --manifest-path ~/haku_shell/tools/haku-info/Cargo.toml
cargo test --locked --manifest-path ~/haku_shell/tools/haku-info/Cargo.toml
python3 ~/haku_shell/tools/haku-info/test_worker.py
```

Comparación real: mismos 92 atajos y mismos campos del sistema, excepto `wm`
(ahora Niri en lugar de Hyprland; la UI ya mostraba Niri por su override).
El helper omite la consulta inútil a hyprctl en Niri y usa el mismo fallback DRM.
Pacman, lspci y lscpu siguen siendo herramientas externas cuando se necesitan,
con límite de 8 s por comando; no se sustituyen consultas por datos inventados.

Medianas de 10 ejecuciones en esta sesión:
- Atajos: Python 40,99 ms; Rust 5,50 ms.
- Información estática: Python 904,94 ms; Rust 783,91 ms.
- Reproductores instalados: Python 162,26 ms; Rust 11,24 ms (15 ejecuciones),
  mismos 7 reproductores en esta sesión.

El trabajo de herramientas externas permanece; no se ha medido ahorro global
de RAM/temperatura. Las pruebas no modifican configuración, paquetes ni hardware.
