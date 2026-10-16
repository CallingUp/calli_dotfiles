# Paquetes

Para instalar, basta con `./install.sh`: el asistente incluye las dependencias
y permite elegir Niri normal o SHORiN en Arch/derivados. La receta fijada del
fork se puede revisar en `../installer/niri-shorin/PKGBUILD`.

La lista vigente por familia está en `../installer/packages.json` y la usa
`../install.sh --dependencies`. `core-packages.txt` es histórica y contiene
Waybar/Noctalia: **no la uses para instalar la shell actual**.

```bash
./install.sh --dry-run --dependencies
```

Consulta `../docs/INSTALL.md`. Noctalia, Waybar y sus parches no se instalan.
