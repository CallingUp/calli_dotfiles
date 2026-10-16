# Niri en calli_dotfiles

[Documentación](../../docs/README.md) · [Instalación](../../docs/INSTALL.md)

Ejecuta `./install.sh` desde la raíz: el asistente elige el teclado y, en Arch,
permite instalar Niri normal o el fork SHORiN. En ambos casos usa el perfil
portable por defecto. Elegir un compositor y elegir un perfil son cosas distintas.

El instalador ofrece dos perfiles:

- **Portable**: `installer/niri-portable.kdl`, para Niri estándar reciente,
  también compatible con SHORiN, con detección automática de pantallas y teclado configurable.
- **Personal**: los KDL de esta carpeta, como ejemplo avanzado. Necesitan el
  fork SHORiN; revisa hardware, teclado, reglas y atajos antes de usarlos.

La opción avanzada `--shorin` instala el paquete del fork solo en Arch/derivados;
`--profile personal` selecciona los KDL avanzados, pero no instala por sí misma
el compositor. No copies el perfil personal sobre otro equipo sin revisarlo. El instalador
valida el KDL antes de reemplazar archivos y adapta las rutas del usuario.

## Módulos del perfil avanzado

`config.kdl` incluye arranque, entorno, entrada, salidas, layout, atajos,
reglas, efectos, acentos y selector de ventanas. Los ajustes específicos del
fork no se trasladan automáticamente al perfil portable.

La interfaz actual es QuickShell, no Waybar ni Noctalia. El servicio de usuario
`haku-quickshell.service` gestiona la shell; evita arrancar una segunda instancia.

Consulta [la guía de instalación](../../docs/INSTALL.md) y
[los controles de las islas](../../docs/edge-bar.md).
