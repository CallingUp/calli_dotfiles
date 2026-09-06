# Shell Haku: Niri, Waybar, Kitty y Fish

## Arquitectura

- Niri gestiona ventanas y composición.
- Waybar Haku Neon es la única barra visible.
- Noctalia aporta launcher, paneles, OSD y notificaciones.
- Awww usa un daemon normal y otro dentro del backdrop de Niri.
- Fish contiene funciones y la guía `guide`.
- El acento dinámico vive en `~/.local/state/haku_theme/`.

## Configuraciones principales

```text
~/.config/niri/
~/.config/waybar/neon/
~/.config/kitty/kitty.conf
~/.config/rofi/
~/.config/noctalia/config.toml
~/.config/fish/config.fish
~/.config/font/config
```

Ejecuta `guide` para ver accesos rápidos.

## Wallpaper y backdrop

`set-wallpaper` guarda la imagen actual y genera el fondo difuminado persistente:

```text
~/.local/state/haku_theme/current_wallpaper
~/.local/state/haku_theme/blurred-backdrop.png
```

Al iniciar Niri, `haku-wallpaper-restore` espera ambos daemons de Awww y carga cada imagen en su namespace. Para comprobarlos:

```console
$ awww query
$ awww query -n awww-daemon-backdrop
```

## Fuente global

La familia instalada es Iosevka Nerd Font. Las escalas disponibles son:

```text
font -10   interfaz 10 · Kitty 10.0 · shell 12
font -11   interfaz 11 · Kitty 11.5 · shell 14
font -12   interfaz 12 · Kitty 13.0 · shell 16
font -14   interfaz 14 · Kitty 15.0 · shell 18
```

Configuración: `~/.config/font/config`.

## Fish

El prompt lee `colors.css` cada vez que se dibuja, por lo que cambia después de `sw` sin reiniciar.

```bash
srcfish
guide
font
```

## Fastfetch adaptable

La función `fastfetch` elige un perfil por ancho:

- 110 columnas o más: imagen completa.
- 64–109: compacto.
- menos de 64: mínimo.

Archivos:

```text
~/.config/fastfetch/config.jsonc
~/.config/fastfetch/config-compact.jsonc
~/.config/fastfetch/config-minimal.jsonc
```

## Validación

```bash
niri validate
fish -n ~/.config/fish/config.fish
fish -n ~/.config/fish/functions/fish_prompt.fish
```

No copies configuraciones antiguas completas sobre estas carpetas; fusiona cambios concretos.
