# Haku Shell

Escritorio Haku basado en Niri y QuickShell: tres islas por hover, launcher,
carrusel de wallpapers, clipboard, controles, reproductor, notificaciones y lock.
Paleta fija siamesa para el escritorio; acento dinámico separado para el acceso.

## Contenido

- `config/`: configuraciones de usuario activas.
- `scripts/bin/`: scripts de `~/.local/bin`.
- `docs/`: documentación de uso y mantenimiento.
- `tools/`: helpers Rust, con fallbacks Python y pruebas.
- `installer/`: instalador seguro Arch/Debian/Ubuntu y perfil Niri portable.
- `nix/` y `flake.nix`: módulos NixOS/Home Manager y builds de helpers.
- `optional/` y `patches/`: material histórico; no se instala automáticamente.

## Exclusiones intencionales

No se versionan claves SSH privadas, sesiones/cookies de navegadores, cachés, juegos, compatdata, wallpapers, binarios compilados ni paquetes `.pkg.tar.zst`.

## Restauración segura

Revisa primero qué se copiará:

```bash
./install.sh --dry-run --dependencies --apps --keyboard latam
```

Para aplicar, crea respaldos por archivo en `~/.local/state/haku-installer/backups/`:

```bash
./install.sh --apply --dependencies --build --apps --enable --keyboard latam
```

La instalación de paquetes y compilación son opcionales y explícitas. No añade
repositorios ni instala el fork personal de Niri, drivers o SDDM. El perfil
portable requiere Qt >= 6.9. NixOS usa módulos declarativos, no este comando.

Lee [instalación, requisitos y límites](docs/INSTALL.md) antes de aplicar.
La implementación NixOS y las instalaciones reales Debian/Ubuntu todavía
necesitan validación en sus sistemas; no se promete compatibilidad con todas
las versiones de esas distribuciones.
