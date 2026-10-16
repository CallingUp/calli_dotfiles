# Carrusel experimental Rust / Iced

**Implementación actual:** [carrusel completo](README-FULL.md), binario
`haku-carousel`. El launcher en modo Rust ya usa esa versión con galería,
búsqueda, aplicar y Papelera. Lo que sigue documenta el prototipo histórico y
sus mediciones, no el consumo ni las limitaciones de la implementación completa.

Prototipo independiente. El launcher admite una sustitución **temporal** mediante
un selector de modo; QML se conserva y no cambian keybinds ni autostart.
Iced 0.14, Wayland, dos builds independientes: **tiny-skia por software**
(predeterminada) y **wgpu GPU** (`--no-default-features --features gpu`).
No es una migración de toda la shell ni prueba que Rust consuma menos.

```sh
cargo build --locked --release -j 2 --manifest-path ~/haku_shell/tools/haku-carousel-prototype/Cargo.toml
~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel-prototype
```

Reutiliza el backend local haku-wallpaper para el catálogo y las miniaturas
420×300. Carga tres: la actual y sus vecinas (o las tres primeras si no hay actual).
Se pueden indicar tres rutas de la galería como argumentos para comparar
exactamente las mismas imágenes. No aplica wallpapers, no borra originales,
no busca en la web; solo puede crear miniaturas en la caché habitual.

↑/↓ y rueda: navegar; Escape: salir. La selección es circular entre esas tres
imágenes, no la galería entera. Movimiento ease-out de 210 ms, retargeting al
instante, sin cola de repeticiones. Cinco slots transitorios reutilizan los
mismos tres handles RGBA; en reposo hay tres tarjetas. Los frames solo se
solicitan durante movimiento. Es una ventana normal de Niri, no layer-shell.
El accent se lee del archivo colors.css al iniciar.
El tamaño es fijo (480×820); Niri abre esta ventana normal como flotante,
sin ninguna regla nueva en su configuración. No es todavía una superficie
pegada al borde izquierdo. Escape o el botón/atajo habitual de cierre la terminan.

```sh
cargo test --locked --release -j 2 --manifest-path ~/haku_shell/tools/haku-carousel-prototype/Cargo.toml
python3 ~/haku_shell/tools/haku-carousel-prototype/measure.py
```

La medición abre una ventana, espera ~5 s, navega ~10 s, queda quieta ~5 s y
sale. No tocar la ventana durante esa prueba. Registra CPU de un núcleo y PSS
del proceso; no suma la shell QML que sigue activa. Las muestras cerca de los
cambios de fase se excluyen. Una comparación justa requiere el mismo tamaño,
imágenes, cadencia y renderer comparable. tiny-skia puede ahorrar memoria y
costar más CPU; falta comparar con aceleración GPU antes de decidir.

## Comparación software / GPU

```sh
cargo build --locked --release -j 2 --manifest-path ~/haku_shell/tools/haku-carousel-prototype/Cargo.toml
cp ~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel-prototype ~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel-software
cargo build --locked --release -j 2 --no-default-features --features gpu --manifest-path ~/haku_shell/tools/haku-carousel-prototype/Cargo.toml
cp ~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel-prototype ~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel-gpu
python3 ~/haku_shell/tools/haku-carousel-prototype/compare.py
```

Seis ensayos secuenciales: software/GPU/GPU/software/software/GPU, mismas
tres rutas fijadas al principio, 480×820, 40 movimientos separados 250 ms.
Se excluye el primer segundo de cada fase y se informa la mediana de tres
ensayos, junto con la carga global del sistema. No se cierran aplicaciones.
La GPU se restringe al driver Intel Vulkan mediante variables solo del proceso
de prueba; no cambia el entorno global ni la configuración del compositor.
El logger de wgpu informa el adaptador realmente seleccionado. Esta selección
es específica de este equipo: revisar el ICD si se usa en otro.

`frames` mide intervalos entre eventos de frame de Iced durante animaciones,
no latencia de presentación física ni una medición completa de GPU. PSS no
incluye toda la memoria gráfica/VRAM. Los datos no bastan para atribuir cambios
de temperatura ni demostrar que supera al carrusel integrado en Quickshell.
La comparación QML todavía requiere un ensayo equivalente y restar la base
del proceso compartido; no comparar su PSS total con este único prototipo.

## Prueba como carrusel predeterminado

El launcher versionado `scripts/bin/wallpaper-carousel`, usado por Mod+Comma,
lee `~/.local/state/haku_theme/carousel_backend` (si no existe, usa QML).
En modo Rust ejecuta `haku-carousel` GPU Intel con `--toggle`; una segunda
invocación lo cierra mediante su socket privado. Un lock del runtime impide
duplicados durante el arranque. `--close` solo cierra esta interfaz.

```sh
# Volver al carrusel completo QML:
bash ~/haku_shell/scripts/bin/haku-carousel-mode qml
# Probar otra vez el prototipo Rust:
bash ~/haku_shell/scripts/bin/haku-carousel-mode rust
```

La limitación de tres imágenes correspondía al prototipo inicial, no al
launcher actual. Consultar README-FULL.md para las funciones trasladadas.
No se ha borrado ni cambiado el componente QML; la prueba sigue siendo reversible.

Antes de activar este modo se midió QML sin modificar su código, y después se
guardaron copias de su carpeta y launcher en:
`~/.local/state/haku-backups/carousel-before-rust-20261013/`.
El SHA256 del launcher original y su copia coincidió. No hay commit/push nuevo.
`measure_qml.py` usa un catálogo temporal de tres imágenes enviado por IPC,
sin cambiar la galería ni aplicar wallpapers. Realiza 40 pasos cada 250 ms.
`measure_rust_total.py` mide las mismas tres imágenes y suma PSS/CPU de la shell
que sigue activa y del prototipo. No comparar solo los 42 MiB del prototipo
contra todo el proceso de Quickshell.

### Resultado QML integrado frente a Rust separado

Tres ensayos por implementación, mismas rutas y cadencia; medianas:

| Estado / métrica | QML (shell compartida) | Rust GPU + shell |
|---|---:|---:|
| Base sin carrusel, PSS (MiB) | 80,11 | 80,03 |
| Abierto tras navegar, PSS (MiB) | 88,69 | 122,15 |
| Navegando, PSS (MiB) | 89,32 | 122,33 |
| Navegando, CPU (% de un núcleo) | 18,45 | 13,05 |
| Abierto quieto tras navegar, CPU | 1,25 | 1,00 |

En este ensayo Rust tiene ~29 % menos CPU al navegar, pero añade ~33 MiB de
RAM proporcional total frente a QML. Es una comparación práctica entre estas
dos interfaces, no prueba de superioridad del lenguaje. QML conserva su diseño
440×920 y siete slots reciclados; Rust es 480×820 y cinco slots, con menos
funciones. El catálogo de prueba es de tres imágenes en ambos; no representa
la carga de una galería completa ni búsqueda web. QML recibe pasos vía IPC y
Rust por su tarea interna. Las demás aplicaciones siguieron ejecutándose.

El proceso compartido tiene páginas intercambiadas; durante los ensayos Rust
la suma SwapPss se mantuvo en 76,79 MiB. La tabla muestra RAM residente PSS,
no PSS+swap ni toda la memoria gráfica. No se han medido vatios/temperatura.
El modo Rust se deja activo solo para probar; si se prioriza RAM o funciones
completas, volver a QML es la opción más conservadora con estos datos.

## Primera medición local (2026-10-13)

Build release, 480×820, fuente monospace, tres miniaturas:

| Fase | CPU (% de un núcleo) | PSS media (MiB) |
|---|---:|---:|
| Inicio/reposo, ~5 s | 4,40 | 29,41 |
| Navegación automática, ~10 s | 84,67 | 29,57 |
| Reposo posterior, ~5 s | 0,50 | 29,60 |

El inicio incluye calentamiento de fuentes/renderizador. Solo 5/10/4 muestras,
sin aislamiento de la carga del sistema. La inspección visual usó una captura
de esta ventana durante el ensayo. Estos datos no son una comparación controlada
con QML. La carga durante animación es demasiado alta para recomendar esta build
como sustituto; el siguiente experimento debe comparar el backend GPU de Iced.
El primer ensayo, con diferente fuente/tamaño de ventana, no es comparable.
Los cuatro tests comprueban wrap, duración, curva y ausencia de cola tras soltar.

## GPU: tres ensayos por backend (2026-10-13)

Mismas tres imágenes (Angel1.png, BG16x9.jpg, HJGF4cpasAAJAhf.jpeg), misma
ventana, fuente y movimientos. Sin capturas durante las mediciones. Medianas
de las medias por ensayo:

| Métrica | Software | Intel Vulkan |
|---|---:|---:|
| CPU al navegar (% de un núcleo) | 85,79 | 11,68 |
| PSS al navegar (MiB) | 28,32 | 42,43 |
| CPU en reposo posterior | 0,40 | 0,00 |
| PSS en reposo posterior (MiB) | 28,12 | 42,47 |
| p95 de intervalo de eventos frame (ms) | 20,26 | 7,12 |

Intel UHD Graphics (CML GT2), Mesa 26.2.4, Vulkan; NVIDIA no seleccionada.
CPU de navegación ~86 % menor que la build software, a cambio de ~14 MiB PSS.
0,00 % es redondeo dentro de muestras breves, no trabajo literalmente nulo.
Carga global durante los ensayos: software 12,71–14,46 %, GPU 8,80–9,30 %;
incluye el propio prototipo y compositor, no aísla la carga de otras apps.
No mide consumo eléctrico, temperatura ni toda la memoria del driver/GPU.
No demuestra todavía ventaja frente al carrusel QML compartido.

Para abrir la build GPU de prueba sin cambiar atajos:

```sh
WGPU_POWER_PREF=low WGPU_BACKEND=vulkan VK_DRIVER_FILES=/usr/share/vulkan/icd.d/intel_icd.json ~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel-gpu
```
