# Niri y Haku

El instalador ofrece dos perfiles:

- **Portable**: `installer/niri-portable.kdl`, para Niri estándar reciente,
  con detección automática de pantallas y teclado configurable.
- **Personal**: los KDL de esta carpeta, como ejemplo avanzado. Necesitan el
  fork SHORiN; revisa hardware, teclado, reglas y atajos antes de usarlos.

No copies el perfil personal sobre otro equipo sin revisarlo. El instalador
valida el KDL antes de reemplazar archivos y adapta las rutas del usuario.

## Módulos del perfil avanzado

`config.kdl` incluye arranque, entorno, entrada, salidas, layout, atajos,
reglas, efectos, acentos y selector de ventanas. Los ajustes específicos del
fork no se trasladan automáticamente al perfil portable.

La interfaz actual es QuickShell, no Waybar ni Noctalia. El servicio de usuario
`haku-quickshell.service` gestiona la shell; evita arrancar una segunda instancia.

Consulta [la guía de instalación](../../docs/INSTALL.md) y
[los controles de las islas](../../docs/edge-bar.md).
