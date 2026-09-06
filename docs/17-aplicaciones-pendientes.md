# Aplicaciones pendientes y YTMDesktop

## YouTube Music Desktop

Instalado de forma portátil desde el RPM oficial de YTMDesktop v2.0.11:

```text
/mnt/Extra-Data/YTMDesktop/
├── app/          programa extraído
├── config/       sesión, preferencias y caché
├── downloads/    RPM y checksum originales
└── themes/       CSS recuperados y tema Haku
```

Ocupa aproximadamente 413 MiB. Se abre desde el menú de aplicaciones, con `ytmdesktop` o mediante `Mod+M`.

Tema activo:

```text
/mnt/Extra-Data/YTMDesktop/themes/Haku Dynamic.css
```

`haku-ytmd-theme` genera ese archivo desde `archivo.css`, la última revisión recuperada de `Cosmic Cyan.css`. Ambos archivos son idénticos salvo por ocho valores de paleta. `set-wallpaper` lo vuelve a generar con el accent actual. También se conservó `ytmd-original.css` sin modificar.

El comando `ytme` abre `archivo.css` en Nano y regenera el tema dinámico al cerrar el editor. No es un lanzador de la aplicación y no se incluye en `guide`.

La aplicación no arranca automáticamente para mantener bajo el consumo idle. YTMDesktop continúa donde quedó y se integra con MPRIS, Waybar y Haku Media.

## Estado del plan de aplicaciones

### Completado

- Git: instalado.
- SSH: instalado y claves/configuración recuperadas.
- Helium: instalado y perfil fusionado.
- MPV: instalado y configuración presente en `~/.config/mpv`.
- YouTube Music Desktop: instalado y tematizado en Extra-Data.

### Pendiente de instalación

- Git LFS: se dejó explícitamente para más adelante.
- Docker y Docker Compose: no están instalados; revisar de nuevo si aparece alguna configuración personal antes de instalarlos.
- FL Studio: instalar desde cero más adelante, sin migrar la instalación antigua.

### Omitido por decisión

- Datos antiguos de Visual Studio Code: no se trasladaron; Code sí está instalado actualmente.
- OBS Studio: no se trasladó ni está instalado.
- Thunderbird: no se trasladó ni está instalado.
- Bottles/Wine: no se trasladaron ni están instalados.
- Videos personales: no se trasladaron.

Antes de continuar con otra aplicación hay que confirmar si pertenece al plan original o fue una sugerencia descartada.
