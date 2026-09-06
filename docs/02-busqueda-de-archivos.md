# Buscar archivos y contenido

## Buscar nombres rápidamente

`rg --files` enumera archivos respetando exclusiones comunes:

```bash
rg --files ~/.config
rg --files ~/.config | rg 'kitty|waybar|rofi'
```

Para todo el sistema de archivos se usa `find`:

```bash
find ~/Documents -type f
find ~/Pictures -type f -iname '*.png'
find /mnt/Linux-Data/FICON -type d -name .git -prune
```

- `-type f`: archivos.
- `-type d`: directorios.
- `-iname`: nombre ignorando mayúsculas.
- `-maxdepth`: limita profundidad.
- `-prune`: evita entrar en una carpeta encontrada.

## Buscar texto dentro de archivos

```bash
rg 'API_KEY' /mnt/Linux-Data/FICON/1
rg -n -i 'error|warning' archivo.log
rg -l 'texto' ~/.codex/sessions
```

- `-n`: número de línea.
- `-i`: ignora mayúsculas.
- `-l`: muestra solo los archivos coincidentes.
- `-C 3`: añade tres líneas de contexto.

No imprimas el contenido de `.env`, claves o tokens en una terminal compartida. Para comprobar existencia sin revelar valores:

```bash
find proyecto -maxdepth 2 -name '.env' -printf '%p\n'
```

## Buscar archivos grandes

```bash
du -sh ~/Downloads/* 2>/dev/null | sort -h
du -x -d 2 -h ~ 2>/dev/null | sort -h | tail -30
find ~/Downloads -type f -size +500M -printf '%s %p\n' | sort -n
```

- `du`: espacio realmente utilizado.
- `-x`: no cruza a otros sistemas de archivos.
- `-d 2`: profundidad máxima.
- `2>/dev/null`: oculta errores de permisos, no resultados normales.

## Buscar archivos recientes

```bash
find ~/Documents -type f -mtime -7 -printf '%TY-%Tm-%Td %TH:%TM %p\n'
```

`-mtime -7` significa modificados durante los últimos siete días.

## Ejemplo usado en la auditoría

```bash
find ~/.codex/sessions -type f -name '*.jsonl'
rg -l '"cwd":"/mnt/linux-data/FICON/1"' ~/.codex/sessions
```

Esto permitió localizar conversaciones de Codex relacionadas con FICON sin buscar manualmente archivo por archivo.

