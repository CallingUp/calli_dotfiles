# Wallpapers: `sw`, `sww` y `swr`

Estos tres comandos de Fish gestionan la biblioteca de fondos Haku desde Kitty. Cada uno tiene una responsabilidad distinta:

| Comando | Función |
| --- | --- |
| `sw` | Elegir y aplicar un fondo que ya existe localmente. |
| `sww` | Buscar fondos en Wallhaven, previsualizarlos, guardar uno y aplicarlo. |
| `swr` | Enviar fondos locales a la Papelera sin salir del selector. |

Todos usan `fzf` como menú y `kitten icat` para las previsualizaciones dentro de Kitty.

## Rutas que usan

```text
~/Pictures/Wallpapers/              biblioteca local principal
~/Pictures/Wallpapers/Wallhaven/    fondos elegidos desde la web
~/Pictures/temp/page/               diez previews activas de sww
~/.local/bin/sww                    selector web
~/.local/bin/set-wallpaper          aplica el fondo y actualiza el tema Haku
~/.config/fish/config.fish          funciones sw y swr
```

`~/Pictures/temp/page/` es una carpeta temporal intencionalmente fija. Esto permite que la ruta que recibe Kitty sea siempre de la forma:

```text
/home/calli/Pictures/temp/page/wallhaven-<id>.jpg
```

No almacena una biblioteca adicional: `sww` borra su contenido al cambiar de página y al cerrarse.

## `sw`: elegir un fondo local

Ejecuta:

```console
$ sw
```

Flujo:

1. Busca imágenes directamente dentro de `~/Pictures/Wallpapers/`.
2. Muestra sus nombres en `fzf` y una preview a la derecha.
3. Al pulsar Enter, llama a `set-wallpaper` con la imagen elegida.
4. `set-wallpaper` actualiza Awww, recuerda el fondo para el siguiente inicio y regenera el acento dinámico Haku.

`sw` no busca dentro de subcarpetas. Los fondos que estén en `Wallpapers/Wallhaven/` se gestionan con `swr` o se pueden mover manualmente a la carpeta principal si se desea que aparezcan en `sw`.

Pulsa `Esc` para cancelar sin cambiar el fondo.

## `sww`: buscar en Wallhaven

Ejecuta:

```console
$ sww
```

Primero pide una búsqueda. Puedes escribir palabras como `anime landscape`, o dejarla vacía para ver fondos recientes.

### Filtros aplicados

La búsqueda solicita a Wallhaven solamente:

- Categorías General y Anime.
- Contenido SFW.
- Relación 16:9.
- Resolución exacta `1920x1080`.
- Orden por fecha de incorporación.

La diferencia importante es entre `atleast=1920x1080` y `resolutions=1920x1080`: el primero acepta resoluciones mayores, mientras que el segundo exige exactamente 1920×1080. `sww` usa el segundo.

### Descarga y páginas

Cada página visible contiene diez resultados:

1. Descarga los diez fondos completos en `~/Pictures/temp/page/`.
2. Usa hasta cuatro descargas en paralelo.
3. Muestra el selector y la preview local; no depende de una preview remota lenta.
4. Al elegir `→ Página siguiente` o `← Página anterior`, elimina las imágenes de la página actual y descarga las diez de la página solicitada en la misma carpeta fija.

En el menú, la primera columna interna es el nombre real del archivo. Por eso el preview usa:

```text
/home/calli/Pictures/temp/page/{1}
```

`{1}` significa “solo el primer campo de la fila de FZF”. Usar `{}` incluiría también resolución y categoría, produciendo una ruta que no existe y una preview vacía.

### Elegir o cancelar

Al pulsar Enter sobre un fondo:

1. El archivo elegido se mueve a `~/Pictures/Wallpapers/Wallhaven/`.
2. Se ejecuta `set-wallpaper` para aplicarlo y actualizar los colores Haku.
3. Las otras nueve descargas temporales se eliminan.

Si pulsas `Esc`, no se guarda ningún fondo y se limpia la página temporal. La carpeta contenedora `~/Pictures/temp/` permanece vacía para la siguiente ejecución.

Dependencias:

```text
curl   consulta y descarga desde Wallhaven
jq     interpreta la respuesta de la API
fzf    selector interactivo
kitten preview gráfico de Kitty
```

## `swr`: enviar fondos a la Papelera

Ejecuta:

```console
$ swr
```

`swr` busca de forma recursiva en `~/Pictures/Wallpapers/`, por lo que también muestra `Wallpapers/Wallhaven/`.

Flujo:

1. Selecciona un fondo y revísalo en la preview.
2. Pulsa Enter: `gio trash` lo envía a la Papelera.
3. El selector se reconstruye y sigue abierto para elegir otro fondo.
4. Pulsa `Esc` o elige `← Salir` para cerrar.

No usa `rm`: enviar a la Papelera permite restaurar un archivo eliminado por error desde el gestor de archivos. Un fondo que está aplicado puede enviarse a la Papelera, pero seguirá visible hasta que apliques otro o reinicies la sesión de Awww.

Si una terminal abierta antes de crear o actualizar `swr` no reconoce el comando, recarga las funciones:

```console
$ source ~/.config/fish/config.fish
```

## Cuando no aparece una preview

Primero comprueba que estás usando Kitty, no otra terminal:

```console
$ echo $TERM
xterm-kitty
```

Para `sww`, mientras el selector esté abierto, verifica que realmente existan los archivos descargados:

```console
$ find ~/Pictures/temp/page -maxdepth 1 -type f
```

No borres `~/Pictures/temp/page/` mientras `sww` está abierto: es la ruta desde la que `icat` lee las previews. Si una ejecución se interrumpe de forma forzada y deja imágenes temporales, puedes inspeccionarlas y luego eliminar exactamente esa carpeta:

```console
$ rm -rf -- /home/calli/Pictures/temp/page
```

Ese último comando elimina solo previews temporales, no la biblioteca de `Wallpapers`.

## Lectura técnica del código

Esta sección no solo dice qué hace cada comando: explica cómo leer sus líneas para poder adaptarlas sin romper el flujo.

### Cómo ver el código con números de línea

```console
$ nl -ba ~/.config/fish/config.fish | sed -n '90,150p'
$ nl -ba ~/.local/bin/sww | sed -n '1,180p'
```

`nl -ba` agrega números incluso a las líneas vacías. `sed -n '90,150p'` limita la salida al rango indicado. Es preferible a abrir un archivo largo cuando quieres discutir o modificar una línea concreta.

### `sw` línea por línea

La parte central de `sw` es equivalente a:

```fish
set img (find /home/calli/Pictures/Wallpapers/ -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) -printf "%f\n" | fzf --preview "kitten icat ... /home/calli/Pictures/Wallpapers/{}")
```

- `set img (...)` es sustitución de comandos de Fish: ejecuta todo lo que está entre paréntesis y guarda la línea elegida por FZF en la variable `img`.
- `find /ruta` recorre la ruta indicada.
- `-maxdepth 1` impide descender a subcarpetas. Por eso `sw` no muestra `Wallpapers/Wallhaven/`.
- `-type f` descarta directorios.
- `\( ... \)` agrupa condiciones para `find`; se escapa porque los paréntesis sin escapar son especiales para el shell.
- `-iname` compara extensiones sin importar mayúsculas/minúsculas. `-o` significa “o”.
- `-printf "%f\n"` devuelve solo el nombre base; por ejemplo, entrega `fondo.jpg`, no su ruta completa.
- `|` pasa esa lista a `fzf`.
- `--preview "... {}"` hace que FZF reemplace `{}` por la fila actualmente resaltada. Como la fila es solo `fondo.jpg`, la ruta final es válida.
- `--place=$FZF_PREVIEW_COLUMNSx$FZF_PREVIEW_LINES@0x0` indica a Kitty el tamaño y esquina de la zona de preview. Esas dos variables las proporciona FZF al proceso de preview.

Después:

```fish
if test -n "$img"
    set wallpaper_path "/home/calli/Pictures/Wallpapers/$img"
    set-wallpaper "$wallpaper_path"
end
```

`test -n` significa “la cadena no está vacía”. Si presionas Esc, FZF no entrega selección y evita aplicar nada. Las comillas conservan correctamente rutas con espacios.

### `swr`: bucle y eliminación recuperable

El selector usa este patrón:

```fish
while true
    set img (begin
        find "$wallpaper_root" -type f ... -printf "%P\n"
        echo "$exit_item"
    end | fzf ...)

    if test -z "$img"; or test "$img" = "$exit_item"
        break
    end

    gio trash "$wallpaper_root/$img"
end
```

- `while true` crea un bucle infinito intencional: el menú vuelve a abrirse tras cada eliminación.
- `begin ... end` permite construir varias líneas antes de pasarlas por `| fzf`.
- `%P` en `find -printf` produce una ruta relativa a la carpeta inicial. Si el archivo es `Wallhaven/fondo.jpg`, FZF lo ve así, pero `swr` puede reconstruir la ruta absoluta al anteponer `$wallpaper_root/`.
- `echo "$exit_item"` agrega una fila artificial llamada `← Salir`.
- `test -z` detecta Esc/cancelación. `test "$img" = "$exit_item"` detecta la fila Salir. `break` termina el bucle, no Fish.
- `gio trash` usa la especificación de Papelera de Linux; mueve el archivo a la papelera del usuario y guarda metadatos para restaurarlo. A diferencia de `rm`, no elimina el contenido inmediatamente.

Después de cada `gio trash`, la siguiente vuelta de `while` ejecuta `find` otra vez; por eso el archivo enviado a la Papelera desaparece de la lista sin cerrar `swr`.

### `sww`: estructura de Bash

`sww` no es una función de Fish sino un ejecutable Bash. Las primeras líneas son:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- El *shebang* pide ejecutar el archivo con Bash disponible en `PATH`.
- `-e` detiene el script ante un comando que falle.
- `-u` convierte una variable no definida en error, evitando usar rutas vacías por accidente.
- `pipefail` hace que un pipeline falle si falla cualquiera de sus partes, no solo el último comando.

La sesión temporal se crea así:

```bash
temp_root="$HOME/Pictures/temp"
page_dir="$temp_root/page"
session_dir="$(mktemp -d "$temp_root/sww.XXXXXX")"
trap 'rm -rf "$session_dir" "$page_dir"' EXIT
```

- `mktemp -d` crea un directorio único y evita colisiones entre ejecuciones para los JSON e índices internos.
- `page_dir` es deliberadamente estático: contiene solo los diez archivos de la página visible y permite una ruta simple para `icat`.
- `trap ... EXIT` ejecuta la limpieza tanto al aplicar un fondo como al cancelar o al terminar normalmente. El `rm -rf` está limitado a dos rutas creadas/conocidas por el script, nunca a `Pictures/Wallpapers`.

### Consulta de Wallhaven

La petición utiliza `curl` con pares separados:

```bash
curl --get "$api_url" \
  --data-urlencode "q=$query" \
  --data-urlencode 'purity=100' \
  --data-urlencode 'resolutions=1920x1080'
```

- `--get` construye una URL de consulta HTTP GET.
- `--data-urlencode` escapa correctamente espacios, acentos y símbolos de tu búsqueda; no conviene concatenar el texto del usuario directamente a una URL.
- `purity=100` solicita contenido SFW.
- `resolutions=1920x1080` exige ese tamaño exacto. No debe cambiarse por `atleast=1920x1080` si no quieres 2560×1440, 3840×2160 u otras resoluciones mayores.

`jq` lee el JSON de respuesta y obtiene, por cada resultado, ID, resolución, categoría y URL del archivo. El script guarda esa información en un TSV: valores separados por tabulaciones. Ese formato es sencillo de procesar con `awk` y seguro para rutas normales de Wallhaven.

### Cuatro descargas a la vez

Dentro del bucle de descarga aparece este patrón:

```bash
curl ... --output "$file" &
((active += 1))
wait -n
```

- `&` manda el `curl` al fondo.
- `active` cuenta trabajos en curso.
- Cuando hay cuatro, `wait -n` espera al primero que termine antes de iniciar otro.

Así nunca hay más de cuatro descargas paralelas: se aprovecha la conexión sin saturar red, disco o Wallhaven. Al final, otro `while` espera los trabajos que aún queden.

### Índice y preview de `sww`

Tras descargar, `find "$page_dir" -type f -size +0c` conserva solo archivos existentes y no vacíos. Luego FZF recibe filas similares a:

```text
wallhaven-abcd12.jpg    1920x1080    general
```

Por esa razón la preview debe usar `{1}`:

```bash
--preview "kitten icat ... /home/calli/Pictures/temp/page/{1}"
```

Con el delimitador de tabulación, `{1}` significa el primer campo: el nombre del archivo. `{}` significaría toda la fila, incluyendo la resolución y categoría, y Kitty intentaría abrir una ruta inexistente. Este detalle explica por qué el preview de `sww` no puede usar exactamente `{}` como `sw`, aunque ambos llamen al mismo `kitten icat`.

Al confirmar:

```bash
mv "$file" "$target"
set-wallpaper "$target"
```

`mv` conserva el archivo elegido moviéndolo fuera de la zona temporal hacia `Wallpapers/Wallhaven`. Solo después se invoca `set-wallpaper`; así el fondo ya existe en su ruta permanente cuando Awww y el generador de colores lo leen.
