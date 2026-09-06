# Pantalla de inicio Haku

El inicio de sesión usa `greetd` con `noctalia-greeter`. SDDM está instalado, pero no es el display manager activo.

## Resultado

- Usuario seleccionado: `calli`.
- Sesión predeterminada: Niri.
- Monitor: `eDP-1`, escala `1.0`.
- Fuente: Iosevka Nerd Font.
- Avatar: `~/Pictures/fastfetch-icon/icon.png`.
- Fondo: último wallpaper aplicado, nítido y recortado a 1920×1080.
- Tarjeta: vidrio oscuro translúcido con desenfoque localizado detrás del formulario.
- Paleta: negro Haku con accent dinámico extraído del wallpaper.
- La pantalla se apaga tras cinco minutos sin actividad.

## Archivos

| Ruta | Función |
|---|---|
| `~/.local/bin/set-wallpaper` | Aplica el wallpaper y llama al sincronizador del greeter. |
| `~/.local/bin/haku-greeter-sync` | Genera el fondo y la configuración Haku. |
| `~/.local/state/haku_theme/current_wallpaper` | Guarda la ruta del último wallpaper. |
| `/var/lib/noctalia-greeter/greeter.toml` | Configuración activa del login. |
| `/var/lib/noctalia-greeter/wallpaper-haku.jpg` | Fondo nítido con el desenfoque localizado de la tarjeta. |
| `/var/lib/AccountsService/icons/calli` | Avatar que muestra el selector de usuario. |

El greeter corre como el usuario restringido `greeter`. No puede entrar a `/home/calli`, por eso necesita copias legibles dentro de `/var/lib`.

## Uso normal

No hay un comando adicional. Cambiar el wallpaper como siempre actualiza también el próximo inicio de sesión:

```console
$ set-wallpaper ~/Pictures/Wallpapers/imagen.png
```

Para confirmar qué wallpaper quedó guardado:

```console
$ cat ~/.local/state/haku_theme/current_wallpaper
```

Para validar la sintaxis de la configuración:

```console
$ python -c 'import tomllib; tomllib.load(open("/var/lib/noctalia-greeter/greeter.toml", "rb")); print("válido")'
```

## Ajustes estéticos

Se editan en `~/.local/bin/haku-greeter-sync`:

- `-blur 0x18`: intensidad del desenfoque exclusivo de la tarjeta.
- `540x240+690+420`: tamaño y posición del área de vidrio en una pantalla 1920×1080.
- `corner_radius_scale = 1.15`: redondez de controles.
- `surface` y `surface_variant`: fondos negros; el canal alfa de `surface_variant` controla la transparencia.
- `outline`: borde dinámico derivado del wallpaper.
- `timeout = 300`: apagado de pantalla en segundos.

No reinicies `greetd` desde una sesión gráfica: cerraría la sesión. Comprueba los cambios al cerrar sesión o reiniciar. Para diagnosticar un fallo:

```console
$ journalctl -u greetd -b
```
