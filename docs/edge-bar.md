# Barra superior por hover

La barra QuickShell muestra tres líneas de acento: estadísticas junto al reloj
central y bandeja de aplicaciones a su derecha, todas en un grupo centrado con
separación uniforme entre centros (hasta 320 px, adaptable al ancho de pantalla).
Las líneas tienen 1 px de alto y 15 % de opacidad, conservando 6 px de hover.
La isla de workspaces se retiró;
los workspaces y sus atajos de Niri se conservan. Al pasar el
puntero por una línea se revela solamente esa sección. Se conservan los menús,
estilos y funciones existentes.

- Entrada: 80 ms de espera y 160 ms de deslizamiento.
- Salida: 260 ms de tolerancia y 90 ms de deslizamiento.
- No reserva espacio ni redimensiona las ventanas: las secciones son overlays.
- En pantalla completa real se ocultan también las líneas.
- Mod + Abajo fija la barra visible; Mod + Arriba la oculta.
- Los paneles que necesitan teclado permanecen abiertos mientras escribes.
- CPU, RAM y temperatura tienen una isla independiente; no reemplazan el reloj.
- Mod + Izquierda/Derecha conserva acceso alternativo a reloj/estadísticas.
- El worker de estadísticas se detiene al ocultar su isla, salvo que otro panel lo necesite.

Implementación: `config/quickshell/minflair-niri/niri-preview.qml`;
controlador y líneas en `Modules/Bar/Styles/Island/EdgeReveal.qml` y
`EdgeHandle.qml`. El controlador usa eventos y temporizadores de una sola
ejecución, sin sondeo continuo ni proceso adicional.

Pruebas (desde la raíz del repositorio):
`QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/quickshell`.
