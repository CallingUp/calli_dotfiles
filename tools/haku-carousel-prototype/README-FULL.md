# Carrusel completo Rust / Iced

El binario **haku-carousel** sustituye la interfaz QML en modo Rust. El binario
`haku-carousel-prototype` y sus copias software/GPU quedan únicamente para los
ensayos históricos. Los números de aquellos ensayos no describen esta versión.

## Diseño y funciones trasladados

- Panel layer-shell pegado a la izquierda, centrado verticalmente, 440×920
  lógicos como máximo y adaptado a pantallas menores. Superficie exterior
  transparente; no reserva espacio ni modifica las ventanas de Niri.
- Fondo #08090b, esquinas de 22 px, fuente de `fonts.css` y accent de `colors.css`.
  El accent se actualiza por eventos de filesystem, no por sondeo periódico.
- Siete slots reciclados: tarjetas 350×242, paso vertical 220, desplazamiento
  lateral/escala/opacidad según distancia y borde de la seleccionada, como QML.
- Entrada desde la izquierda de 160 ms y giro ease-out de 210 ms. También se
  suaviza el cierre. El movimiento retargetea inmediatamente, sin cola.
- Galería local completa, filtro por palabras sin distinguir mayúsculas y
  selección inicial del fondo actual. No hay límite artificial de tres imágenes.
- Wallhaven: favoritos, SFW, categorías 111, mínimo 1920×1080, 16:9, búsqueda
  con Enter y paginación automática al acercarse al final. Se conserva la clave
  API si ya existe; solo la lee el backend, no se imprime ni se pasa por argv.
- Enter/clic central aplica; clic lateral selecciona. Local y web comparten el
  backend existente de aplicar, descargar, transición y sincronización de tema.
- Supr pide confirmación para Papelera local; no elimina directamente. El fondo
  activo está protegido tanto en la interfaz como en el backend. En resultados
  web Supr solo oculta el resultado durante esa sesión, sin borrar archivos.
- ↑/↓, rueda/trackpad acumulados, Tab, Ctrl+F, Escape y clic fuera. Escape cancela
  primero una confirmación abierta. La búsqueda recibe foco real al cargar.
- Contador, etiquetas de fondo actual, resolución web y mensajes de estado/error.

La interfaz reproduce la estructura y geometría QML, pero no se promete igualdad
píxel a píxel entre motores de fuentes/mezcla Qt e Iced. Se usa la salida activa
de Niri; el QML anterior elegía `screens[0]` (diferencia en multimonitor).

## Ejecutar y volver a QML

El acceso habitual sigue siendo **Mod+Comma**. Una segunda pulsación cierra.

```sh
bash ~/haku_shell/scripts/bin/haku-carousel-mode rust
bash ~/haku_shell/scripts/bin/haku-carousel-mode qml
```

No cambian los keybinds, no hay daemon permanente y QML no fue borrado/modificado.
Si faltan los binarios necesarios, el launcher puede volver a la ruta QML/Python.

```sh
cargo build --locked --release -j 2 --manifest-path ~/haku_shell/tools/haku-wallpaper/Cargo.toml
cargo build --locked --release -j 2 --no-default-features --features full --bin haku-carousel --manifest-path ~/haku_shell/tools/haku-carousel-prototype/Cargo.toml
```

El launcher usa la Intel integrada mediante Vulkan en este equipo. No hace
cambios globales de drivers. Para abrir, usar el launcher; ejecutar directamente
el binario sin las variables del launcher puede elegir otra GPU.
Cargo.lock fija winit-common/core **0.31.0-beta.2**: beta.3 rompe una coincidencia
de enum de iced_exdevtools 0.19.1. No usar `cargo update` sin repetir las pruebas.

## Recursos, procesos y cancelación

Miniaturas JPEG 420×300 compartidas con el backend existente. Se conserva una
ventana de hasta 14 handles durante el giro y normalmente siete en reposo; una
conversión a la vez. Las imágenes antiguas/fallidas fuera de esa ventana se
descartan. No se decodifica el wallpaper original en cada frame.
Solo hay suscripción de frames durante entrada, giro o cierre. Cerrado, la
interfaz, su watcher y socket salen; no se mantiene un proceso oculto.
La animación usa una cadencia máxima nominal de 60 actualizaciones/s, con la
misma duración y curva. Las tarjetas fuera del viewport se descartan antes de
crear geometría/texto; las prioridades de miniaturas no se recalculan en cada
tick, sino al cruzar una posición o recibir cambios de estado.
El fondo y siete slots de tarjeta usan cachés de geometría con invalidación por
contenido/movimiento/color/tamaño. Se reutiliza almacenamiento gráfico entre
frames; la caché está acotada y desaparece al cerrar la interfaz.
El socket vive en XDG_RUNTIME_DIR y un lock evita instancias duplicadas.

## Prueba de tarjetas con shader GPU

La ruta Rust usa ahora `card_gpu.rs` y `card_gpu.wgsl` por defecto: dos triángulos
por tarjeta, uniforms de transformación de 112 bytes y caché de texturas que
sigue los handles vivos (máximo 14 más una textura fallback 1×1). No crea otro
dispositivo GPU ni un render pass por tarjeta: reutiliza los de Iced. Las
miniaturas RGBA se suben al entrar en la caché, no en cada frame. Texto, campos,
diálogos, foco, backend y cadencia de animación permanecen en Iced.
Las tarjetas y sus captions se intercalan para preservar la superposición.

Canvas anterior sigue incluido para comparar o volver temporalmente:

```sh
# Cerrar primero el carrusel si está abierto.
~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel --close
HAKU_CAROUSEL_RENDERER=canvas ~/.local/bin/wallpaper-carousel
# Sin esa variable, el launcher utiliza shader GPU.
```

`--status` informa `cardRenderer`, `gpuTextures` y `gpuUploads`.
Comparación repetible de las tres rutas:

```sh
python3 -B ~/haku_shell/tools/haku-carousel-prototype/measure_full.py --modes canvas,gpu,qml
```

No interactuar durante la prueba. El test verifica que la interfaz sigue abierta;
una ronda interrumpida no se considera una reducción de consumo.

Las consultas/miniaturas se ejecutan de forma asíncrona y se cancelan como
grupos de procesos dedicados al cerrar. Una operación explícita de Apply/Trash
ya confirmada puede terminar bajo su timeout de 150 s, para no interrumpir
escrituras atómicas de estado ni dejar wallpaper/backdrop desincronizados.
La transición y sincronización siguen siendo los scripts del backend original.

## Pruebas y diagnóstico

```sh
cargo test --locked --release -j 2 --no-default-features --features full --bin haku-carousel --manifest-path ~/haku_shell/tools/haku-carousel-prototype/Cargo.toml
~/haku_shell/tools/haku-carousel-prototype/target/release/haku-carousel --status
python3 ~/haku_shell/tools/haku-carousel-prototype/smoke_full.py
```

20 pruebas de frontend cubren filtro, Unicode, wrap, caché, movimiento sin cola,
respuestas antiguas, paginación, Papelera protegida, confirmación/cancelación,
teclado, rueda, acciones duplicadas, errores y cancelación de procesos.
También verifican alineación de uniforms WGSL y slots GPU sin colisiones. No
modifican wallpapers reales. Se vuelven a ejecutar las 29 pruebas del backend
(5 Rust, 18 del worker, 6 del backend anterior con fixtures).

En sesión se verificó: galería real, foco `searchFocused=true`, diseño mediante
captura solo del panel, consulta Wallhaven y aplicar el fondo ya activo con
respuesta `unchanged`. No se enviaron wallpapers del usuario a la Papelera como
prueba. Los cambios de fondo que haga el usuario en la UI usan el backend real.

El consumo anterior del prototipo de tres imágenes ya no es una comparación
válida: esta versión incluye búsqueda, capa fullscreen transparente, controles
y galería completa. No se afirma ahorro de RAM/temperatura sin medirla de nuevo.
