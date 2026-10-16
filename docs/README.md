# Documentación de calli_dotfiles

[Proyecto](../README.md) · [Instalación](INSTALL.md)

- [Instalación multiplataforma, requisitos y restauración](INSTALL.md).
- [Islas y controles por hover](edge-bar.md).
- [Paleta fija y colores de las pantallas de acceso](fixed-palette.md).
- [Configuración portable y personal de Niri](../config/niri/README.md).
- [Port de Minflair, alcance y atribución](../config/quickshell/minflair-niri/PORT.md).
- [Bloqueo independiente y prueba segura](../config/quickshell/haku-lock/README.md).
- [Scripts instalados](../scripts/README.md).

La instalación recomendada comienza con `./install.sh` desde la raíz del repo.
El asistente usa el perfil portable; en Arch ofrece Niri normal o SHORiN.
La rama pública es `main`. Las ramas históricas y archivos privados no forman
parte de estas guías.

Los README de cada herramienta en `tools/` explican su compilación y pruebas.
Las notas de una máquina concreta, guías personales de administración y resultados
locales de benchmarks no forman parte de la documentación pública.

La instalación portable no presupone el hardware, usuario, discos ni perfiles
de aplicaciones de la persona que mantiene el proyecto.

## Componentes

- [Portapapeles](../config/quickshell/haku-clipboard/README.md).
- [Carrusel QML](../config/quickshell/haku-wallpaper/README.md).
- [Selectores QML](../config/quickshell/haku-menu/README.md).
- [Panel de atajos](../config/quickshell/haku-shortcuts/README.md).
- [Actividad y notificaciones](../config/quickshell/minflair-niri/Modules/Activity/README.md).
- [Timeline MPRIS](../config/quickshell/minflair-niri/Modules/Music/TIMELINE.md).
- [Paquetes y fork SHORiN](../packages/README.md).

Los documentos bajo `config/waybar/` y `tools/haku-carousel-prototype/`
son referencias históricas o experimentales, no pasos de instalación.
