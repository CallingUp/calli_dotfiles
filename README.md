# Haku Shell

Configuración reproducible del escritorio Niri de CallingUp: Waybar Haku Neon, Noctalia, Kitty, Fish, Rofi, Fastfetch, fuentes y scripts locales.

## Contenido

- `config/`: configuraciones de usuario activas.
- `scripts/bin/`: scripts de `~/.local/bin`.
- `docs/`: documentación de uso y mantenimiento.
- `optional/noctalia-plugins/`: Haku Media archivado; no se activa automáticamente.
- `patches/`: diferencias fuente y receta de paquete para Waybar y Noctalia.
- `packages/`: dependencias base de la shell.

## Exclusiones intencionales

No se versionan claves SSH privadas, sesiones/cookies de navegadores, cachés, juegos, compatdata, wallpapers, binarios compilados ni paquetes `.pkg.tar.zst`.

## Restauración segura

Revisa primero qué se copiará:

```bash
./install.sh
```

Para aplicar, el script crea un respaldo en `~/backups/` antes de reemplazar cualquier configuración:

```bash
./install.sh --apply
```

El instalador no instala paquetes ni compila los parches. Esas acciones se documentan por separado para evitar cambios inesperados en un equipo nuevo.

## Remoto

El repositorio usa el alias SSH `github.com-callingup`, de modo que no altera la clave existente de FICON.
