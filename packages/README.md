# Paquetes de calli_dotfiles

[Documentación](../docs/README.md) · [Instalación](../docs/INSTALL.md)

Para instalar, basta con `./install.sh`: el asistente incluye las dependencias
y permite elegir Niri normal o SHORiN en Arch/derivados. La receta fijada del
fork se puede revisar en `../installer/niri-shorin/PKGBUILD`.

La lista vigente por familia está en `../installer/packages.json` y la usa
`./install.sh --dependencies` desde la raíz del repositorio. `core-packages.txt` es histórica y contiene
Waybar/Noctalia: **no la uses para instalar la shell actual**.

```bash
./install.sh --dry-run --dependencies
```

SHORiN es una selección explícita: se compila la receta incluida, fijada a una
revisión, sin instalar un helper AUR ni añadir repositorios. Debian/Ubuntu usan
sus repositorios configurados; NixOS usa los módulos declarativos.

Consulta [la guía completa](../docs/INSTALL.md). Noctalia, Waybar y sus parches no se instalan.
