# Carrusel QML de wallpapers

Isla negra pegada al borde izquierdo, esquinas derechas redondeadas, fuente
compartida y acento dinámico observado mediante FileView. No reserva espacio
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

Se mantienen `wallpaper-transition`, `wallpaper-theme-sync`, los archivos de
generación/current_wallpaper y la animación del único backdrop. No se cambia
su renderer ni la sincronización de SDDM.

Pruebas mock (sin aplicar fondos, descargar ni borrar):

```sh
python3 ~/haku_shell/config/quickshell/haku-wallpaper/test_backend.py
```

Respaldo GTK: `~/backups/wallpaper-carousel-qml-20261011/`.
