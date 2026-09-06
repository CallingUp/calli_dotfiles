# Paquetes

`core-packages.txt` enumera las dependencias de usuario de la shell. Revísalo antes de instalarlo en otra máquina:

```bash
yay -S --needed $(tr '\n' ' ' < packages/core-packages.txt)
```

Noctalia y Waybar con parches propios no se instalan desde esa lista; sus cambios fuente están en `../patches/`.
