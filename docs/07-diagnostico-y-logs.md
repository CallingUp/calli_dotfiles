# Diagnóstico y logs

## Método general

1. Reproduce el problema una vez.
2. Anota hora y acción exacta.
3. Comprueba estado, versión y espacio.
4. Consulta logs recientes.
5. Cambia una sola variable.
6. Valida y conserva una ruta de reversión.

## Información básica

```bash
uname -a
cat /etc/os-release
df -h
free -h
systemctl --failed
```

## Journal

```bash
journalctl -b --no-pager
journalctl -b -p warning --no-pager
journalctl -b -k --no-pager
journalctl --user -b --no-pager
journalctl -u servicio -b --no-pager
```

- `-b`: arranque actual.
- `-k`: kernel.
- `-p warning`: advertencias o peor.
- `-u`: unidad concreta.

Buscar patrones:

```bash
journalctl -b -k --no-pager | rg -i 'nvidia|xid|firmware|error'
```

## Logs usados en esta configuración

```bash
tail -100 /tmp/noctalia.log
tail -100 /tmp/waybar-hover.log
tail -100 ~/.local/share/Steam/logs/content_log.txt
```

## Validaciones antes de reiniciar

```bash
fish -n ~/.config/fish/config.fish
niri validate
bash -n ~/.local/bin/set-wallpaper
kitty +runpy 'from kitty.config import load_config; print(load_config("/home/calli/.config/kitty/kitty.conf"))'
```

## Disco lleno

```bash
df -hT
du -x -d 2 -h ~ 2>/dev/null | sort -h | tail -30
du -sh /var/cache/pacman/pkg
lsof +L1
```

No borres el primer archivo grande que aparezca. Clasifica primero: personal, caché, build regenerable o dato activo.

