# Carrusel QML de wallpapers

Isla negra pegada al borde izquierdo, esquinas derechas redondeadas, fuente
compartida y paleta compartida observada mediante FileView. No reserva espacio
ni altera el layout de Niri. Esc o clic fuera cierra.

Siete tarjetas recicladas describen un arco; las vecinas se desplazan y cambian
de escala/opacidad alrededor del centro. Una sola posición animada (210ms,
OutCubic) se redirige al recibir otra pulsación: no hay una cola de rotaciones
que continúe después de soltar. Flechas arriba/abajo y rueda navegan; letras,
espacio y flechas laterales quedan disponibles para editar el buscador.

Enter o clic central aplica. Tab cambia Local/Wallhaven. Wallhaven carga por
defecto favoritos, SFW, categorías 111, mínimo 1920x1080 y 16:9; conserva la
clave opcional `~/.config/haku/wallhaven_api_key`. Ctrl+F inicia otra búsqueda.
Se cargan más páginas al acercarse al final. Supr con búsqueda vacía permite
enviar un fondo local a la Papelera, previa confirmación, nunca el activo;
en Wallhaven oculta el resultado durante esa sesión.

Miniaturas de 420x300, generación secuencial y precarga limitada al entorno de
la selección. Las imágenes originales solo se descargan al aplicar. El caché
está en `~/.cache/haku-wallpaper-carousel/qml`. No se añade un servicio residente.

Optimización QML: las rutas de miniaturas locales ya guardadas se
reciben con el catálogo, evitando procesos de consulta individuales. Solo se
cargan imágenes dentro del viewport o a 64 px de entrar; se conservan las siete
tarjetas, su geometría y precarga de rutas. En 1920×1080 son cinco imágenes
activas en reposo, frente a siete anteriormente. `Image.cache: false` se mantiene
para no acumular una caché global sin límite. El mapa de rutas no se reemplaza
si no cambió. El worker sigue generando caché faltante y las miniaturas web.

La animación conserva 210 ms OutCubic y la entrada 160 ms. No se cambian diseño,
fuente, acento, controles ni comportamiento de aplicar/Papelera. La prueba real
incluye navegación rápida, límites de caché, recuperación si falta un archivo,
compatibilidad con catálogo sin metadatos nuevos y cierre. No aplica fondos.

```sh
python3 -B ~/haku_shell/tools/haku-carousel-prototype/smoke_qml.py
python3 -B ~/haku_shell/tools/haku-carousel-prototype/measure_full.py --modes qml-base,qml-opt
```

La opción interna `optimizeThumbnails: false` en la petición permite medir la
ruta anterior sin reiniciar Qt; el launcher normal usa la optimizada.
Consulta la [metodología de medición](../../../docs/PERFORMANCE.md) para comparar ambas rutas.

El catálogo, búsqueda Wallhaven, miniaturas locales/web, aplicar y Papelera usan Rust mediante
`scripts/bin/haku-wallpaper-worker`, con alternativa Python. HTTPS usa curl.
Se conservan los scripts existentes de transición y sincronización. Python queda
como alternativa si falta el binario; el launcher normal también es Rust. Detalles y compilación:
`tools/haku-wallpaper/README.md`.

El componente vive en `../minflair-niri/Modules/WallpaperCarousel/Carousel.qml`.
El selector intenta abrirlo bajo demanda dentro de la shell principal mediante
`haku-wallpaper-host`; al cerrar, el Loader destruye el componente. `shell.qml`
conserva el modo independiente como alternativa cuando la shell no está disponible.
El mismo atajo alterna abrir/cerrar en ambos modos.

Se mantienen `wallpaper-transition`, `wallpaper-theme-sync`, los archivos de
generación/current_wallpaper y la animación del único backdrop. No se cambia
su renderer ni la sincronización de SDDM.

Pruebas mock (sin aplicar fondos, descargar ni borrar):

```sh
python3 ~/haku_shell/config/quickshell/haku-wallpaper/test_backend.py
```
