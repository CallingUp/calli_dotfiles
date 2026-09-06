# Rendimiento idle de Niri Haku

Medición realizada el 1 de septiembre de 2026 con Helium, Steam y otras aplicaciones cerradas.

## Resultado

- RAM física instalada: 15.4 GiB.
- RAM usada durante la medición: 1.8 GiB.
- RAM disponible: 13.6 GiB.
- Swap usada: 100 KiB.
- Objetivo: menos de 2 GiB; cumplido.

Codex y Kitty estaban abiertos para efectuar la prueba y consumían aproximadamente 265 MiB y 205 MiB de RSS, respectivamente. Al cerrarlos, el escritorio base debería quedar alrededor de 1.4 GiB, dependiendo de memoria compartida y caché.

## Componentes conservados

- Noctalia: shell, launcher, OSD, notificaciones y controles.
- Waybar: única barra visible.
- Dos procesos de Awww: wallpaper normal y backdrop.
- Portal GNOME: compartir pantalla bajo Niri.
- Portal GTK: selectores de archivos e integración de escritorio.
- NetworkManager Applet: indicador de red de la bandeja.
- GNOME Keyring: secretos de Helium y soporte PKCS#11.
- Xwayland: compatibilidad con Steam, juegos y aplicaciones X11.

No se deshabilitaron servicios necesarios para obtener una cifra artificialmente baja.

## Comandos de comprobación

```console
$ free -h
$ ps -eo user,pid,comm,rss,%mem,%cpu,args --sort=-rss | head -n 35
$ systemctl --user --state=running --type=service
```

La columna `used` de `free` es la referencia general. La suma de RSS de `ps` no representa RAM física exacta porque bibliotecas y páginas compartidas se cuentan en más de un proceso.
