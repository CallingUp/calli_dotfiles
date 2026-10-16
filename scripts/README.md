# Scripts de calli_dotfiles

[Documentación](../docs/README.md) · [Instalación](../docs/INSTALL.md)

`bin/` reúne comandos de la shell, wrappers de helpers y utilidades opcionales.
No copies todo el directorio a `~/.local/bin`.

Desde la raíz del repositorio, ejecuta `./install.sh`. El instalador despliega
solo su lista permitida para QuickShell, wallpaper, clipboard, controles y lock.
El perfil portable usa los adaptadores de `installer/` para wallpaper y restore;
no copia el renderer avanzado ni integra SDDM automáticamente.

No instala herramientas de migración, particionado, importación de chats,
limpieza, perfiles de shell ni carga de claves SSH. Las configuraciones y alias
privados no se distribuyen. Los nombres internos `haku-*` se conservan por
compatibilidad aunque el proyecto se llame `calli_dotfiles`.

Los wrappers prefieren helpers Rust compilados y conservan Python cuando falta
el binario. El asistente compila los cinco helpers; `--build` permite hacerlo
explícitamente en el modo avanzado. No mueve ni modifica datos de aplicaciones.
