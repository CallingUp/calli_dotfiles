# Selectores QML

`haku-qml-menu` sustituye las llamadas locales a Rofi conservando los scripts
que realizan cada acción. Se inicia solo al abrir un menú y termina al elegir
o cancelar; no hay otro demonio ni sondeo continuo.

Diseño: negro, acento y fuente de `~/.local/state/haku_theme`, búsqueda,
selección con flechas, Enter, Esc y clic fuera. Letras y espacio siempre
escriben; no se usan como atajos de navegación. Ctrl+Enter devuelve texto
libre incluso si hay resultados. Se conservan Alt+Delete (código 10) y las
teclas personalizadas de los modos de script, más Tab para cambiar de modo.

La compatibilidad cubre los argumentos usados por los scripts migrados, no
pretende reproducir toda la API de Rofi. Los estilos `.rasi` se ignoran: el
diseño compartido está en `shell.qml`. Los metadatos `icon` se muestran en
las filas; `info`/`data` se devuelven a los modos de script. Drun/run abre el
launcher existente. El carrusel GTK actual no se sustituye aquí: no era Rofi.

Los datos temporales, incluido el historial del portapapeles, se guardan en
un directorio privado 0700 de XDG_RUNTIME_DIR y se eliminan al cerrar. No se
envían como argumentos ni se imprimen en los registros de Quickshell.

Pruebas sin acciones reales:

```sh
python3 ~/haku_shell/config/quickshell/haku-menu/test_bridge.py
printf 'Una opción\nOtra opción\n' | haku-qml-menu -dmenu -p Prueba
```

Los menús de captura/grabación conservan sus motores previos. Esto cambia la
interfaz, no valida ni adapta automáticamente sus backends de Hyprland.
No ejecutar acciones de apagado/borrado para probar la apariencia.
