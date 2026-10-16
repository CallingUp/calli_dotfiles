# Panel de atajos

`scripts/bin/haku-shortcuts` alterna el componente bajo demanda en la shell
principal. La UI está en `../minflair-niri/Modules/Shortcuts/Shortcuts.qml`.
El helper Rust `tools/haku-info` vuelve a leer los bindings actuales al abrir;
`shortcuts.py` se conserva como alternativa si falta el binario. No hay consultas
periódicas ni proceso auxiliar residente. `shell.qml` conserva el modo separado
si la shell principal no está disponible. Esc y clic fuera cierran el panel.

Medición de esta sesión: aproximadamente 9 MiB adicionales de PSS abierto.
El clipboard añadió aproximadamente 11 MiB en una medición equivalente. Son
incrementos del proceso principal, no una garantía de ahorro frente a versiones
anteriores ni una comparación del consumo base entre distintas sesiones.
