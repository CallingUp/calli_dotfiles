# Biblioteca Linux de Calli

Esta carpeta documenta el sistema CachyOS, las tareas realizadas durante la migración y una ruta progresiva para aprender Linux sin depender de memorizar comandos.

## Ruta recomendada

1. [Terminal, rutas y ayuda](01-terminal-rutas-y-ayuda.md)
2. [Buscar archivos y contenido](02-busqueda-de-archivos.md)
3. [Copiar, respaldar y sincronizar](03-copias-y-respaldos.md)
4. [Permisos, procesos y servicios](04-permisos-procesos-servicios.md)
5. [Paquetes en CachyOS](05-paquetes-cachyos.md)
6. [Discos, particiones y montajes](06-discos-montajes-fstab.md)
7. [Diagnóstico y logs](07-diagnostico-y-logs.md)

## Configuración realizada

- [Shell Haku: Niri, Waybar, Kitty y Fish](10-shell-haku.md)
- [Steam y biblioteca Extra-Data](11-steam-linux-data.md)
- [Drivers gaming NVIDIA/Intel](12-drivers-gaming.md)
- [Auditoría de Pop!_OS y recuperación de Codex](13-recuperacion-popos-codex.md)
- [Pantalla de inicio Haku con greetd y Noctalia](14-pantalla-inicio-haku.md)
- [Rendimiento idle de Niri Haku](15-rendimiento-idle.md)
- [Por qué se compilaron paquetes Haku](16-compilaciones-haku.md)
- [Aplicaciones pendientes y YTMDesktop](17-aplicaciones-pendientes.md)
- [Wallpapers: sw, sww y swr](18-wallpapers-sw-sww-swr.md)
- [Lectura técnica de comandos del sistema](19-lectura-tecnica-de-comandos.md)

## Convenciones

Los bloques con `$` son comandos de usuario. No escribas el `$`:

```console
$ pwd
/home/calli
```

Los comandos marcados como destructivos pueden borrar o sobrescribir información. Antes de ejecutarlos, resuelve la ruta exacta con `realpath`, `ls` o `find`.

## Reglas de seguridad

- No uses `sudo` por costumbre; úsalo solo cuando el destino pertenezca al sistema.
- No ejecutes `rm -rf` con variables, comodines o rutas que no hayas verificado.
- No copies `.env`, claves SSH, tokens o `auth.json` a repositorios públicos.
- Antes de editar `/etc/fstab`, crea una copia y valida con `findmnt --verify`.
- No reemplaces una carpeta de configuración completa cuando puedas fusionar archivos concretos.
- Si el disco está lleno, detén instalaciones y descargas antes de investigar.

## Estado relevante al crear esta guía

- Sistema: CachyOS, Niri 26.04.
- GPU: Intel UHD + NVIDIA GTX 1650 Mobile.
- Steam está consolidado en `/mnt/Extra-Data/GAMES/SteamLibrary`.
- `/dev/nvme1n1` aporta 465.8 GiB como `Extra-Data`; los 50 GiB antes sin asignar se incorporaron el 6 de septiembre de 2026.
- Proyecto FICON: `/mnt/Linux-Data/FICON/1`.
- La raíz tenía poco espacio libre; consulta `df -h` antes de migraciones grandes.
