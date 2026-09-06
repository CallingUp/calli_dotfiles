# Lectura técnica de comandos del sistema

Este complemento enseña a interpretar los comandos de las guías 01–17. Léelo junto al documento de cada asunto: la otra guía explica qué hacer; esta explica cómo y por qué funciona cada línea.

## Regla común: programa, opciones y argumentos

En `rsync -aHAXv origen/ destino/`, `rsync` es el programa, `-aHAXv` son opciones y las dos rutas son argumentos. El shell expande `~` a `/home/calli`, variables como `$HOME` y sustituciones como `$(date +%F)` antes de iniciar el programa.

Las comillas dobles conservan una ruta con espacios como un solo argumento: `"$HOME/Mis Fondos"`. El código de salida `0` es éxito; Fish lo expone como `$status`. Por eso `a && b` ejecuta `b` solo si `a` funcionó, mientras `a || b` lo ejecuta si `a` falló.

## 01 · Terminal y ayuda

`pwd` pregunta el directorio de trabajo actual. `cd ..` entra al padre; `cd -` usa el directorio anterior guardado por el shell. `ls -lah` combina tres opciones: lista detallada (`l`), incluye ocultos (`a`) y hace legibles los tamaños (`h`).

`type nombre` es más informativo que `command -v nombre` en Fish: distingue ejecutable, función, alias o abreviación. `man` abre el manual local. Una redirección `>` reemplaza un archivo, `>>` añade al final y `2>` redirige solamente mensajes de error; nunca uses una redirección de escritura sin confirmar la ruta destino.

## 02 · Búsqueda

`rg` busca texto y respeta `.gitignore`; `rg --files` solo enumera rutas. `find` pregunta al sistema de archivos y no sigue esas exclusiones. En `find ruta -type f -iname '*.png'`, `-type f` limita a archivos y `-iname` hace la extensión insensible a mayúsculas.

`-prune` evita descender en un resultado: `find proyecto -type d -name .git -prune` no recorre objetos internos de Git. `2>/dev/null` desecha el descriptor de error, mientras `| sort -h` recibe la salida normal. Úsalo para permisos conocidos, no para ocultar errores importantes.

## 03 · Copias y respaldos

`cp -a` conserva estructura y metadatos; `rsync -aHAX` añade preservación de hard links (`H`), ACL (`A`) y atributos extendidos (`X`). Con `-n`, rsync hace una simulación: no escribe. Revisa ese resultado y quita solo `-n` para hacer la misma operación de verdad.

La barra final cambia el significado: `origen/` copia el contenido; `origen` crea una carpeta anidada. `tar -czf archivo.tar.gz rutas` crea (`c`), comprime gzip (`z`) y escribe el archivo (`f`); `tar -tzf` lo lista sin extraer. `sha256sum` verifica igualdad de bytes, no compatibilidad del contenido.

## 04 · Permisos, procesos y servicios

Los modos `rwx` se aplican a propietario, grupo y otros. En `700`, el propietario recibe lectura, escritura y acceso; grupo y otros no reciben nada. En un directorio, `x` permite atravesarlo. `chmod 600 clave` limita una clave privada al dueño; `chmod 777` concede acceso universal y no soluciona un propietario incorrecto.

`pkill` envía `SIGTERM`, que permite cerrar limpiamente. `kill -9` es `SIGKILL`: el proceso no puede guardar ni limpiar recursos. `systemctl --user` controla unidades de tu sesión; sin `--user` controla unidades del sistema. `enable` prepara el próximo inicio, `start` inicia ahora y `enable --now` hace ambos.

## 05 · Paquetes CachyOS

Pacman combina letras: `-Syu` usa sincronización (`S`), refresca las bases (`y`) y actualiza (`u`). `pacman -Qi` consulta un paquete instalado; `-Si` consulta metadatos del repositorio. No hagas actualizaciones parciales en Arch: las bibliotecas y sus consumidores se actualizan como conjunto.

`pacman -Rns` elimina el objetivo, sus dependencias huérfanas y archivos de configuración respaldables. Antes, `pactree -r paquete` muestra qué depende de él. La caché de Pacman contiene paquetes descargados: `paccache -rk1` conserva una revisión de los instalados, mientras `paccache -ruk0` limpia solo paquetes que ya no están instalados.

## 06 · Discos, montajes y fstab

`lsblk` describe dispositivos y particiones; `df` mide espacio de sistemas ya montados; `findmnt` muestra el origen y opciones reales. Un UUID identifica el sistema de archivos aunque cambie el nombre `/dev/nvme…`, por eso se usa en `fstab`.

Una línea fstab tiene seis campos: origen, punto de montaje, tipo, opciones, dump y orden fsck. `nofail` deja iniciar sin el disco; `x-systemd.automount` monta al acceder. `findmnt --verify` valida sintaxis antes de probar `mount /punto`. `mkfs.ext4` no verifica: destruye el sistema de archivos anterior para crear uno nuevo.

## 07 · Diagnóstico y logs

`journalctl -b` filtra por el arranque actual; `-b -1`, por el anterior. `-p warning` es un umbral de severidad, no una búsqueda literal. `-k` limita al kernel y `--user` a servicios de usuario. `rg -i` realiza una búsqueda sin distinguir mayúsculas.

`fish -n`, `bash -n` y `niri validate` analizan sintaxis sin aplicar cambios. Ejecutarlos antes de reiniciar hace visibles errores de configuración. `lsof +L1` encuentra archivos que ya fueron borrados del árbol pero siguen abiertos y reteniendo espacio.

## 10 · Shell Haku

Niri carga una configuración KDL compuesta por archivos incluidos. Separar input, reglas, layout y keybinds permite validar el conjunto y reducir conflictos. Waybar muestra la barra; Noctalia aporta paneles y notificaciones; Awww tiene un daemon normal y otro para el backdrop.

`set-wallpaper` es el punto de entrada correcto porque actualiza imagen, estado persistente y colores dinámicos. Llamar a Awww directamente solo cambia la imagen actual. `awww query` consulta el daemon normal; `awww query -n awww-daemon-backdrop` consulta el de fondo.

## 11 · Steam y Extra-Data

Cada `appmanifest_<appid>.acf` es VDF de Steam: relaciona appid, directorio y tamaño. Hay que validar también `steamapps/common/<installdir>`, no solo contar manifests. `libraryfolders.vdf` registra rutas de bibliotecas; mover archivos sin actualizarlo hace que Steam no los descubra.

`rsync --remove-source-files` borra cada archivo fuente solo tras copiarlo bien, pero deja directorios. `--ignore-existing` protege un archivo válido ya copiado del destino; fue importante para no reemplazar el runtime completo con una copia parcial.

## 12 · Drivers y gaming

`lspci -k` asocia hardware PCI con drivers del kernel. `modinfo -k VERSION` inspecciona un módulo para un kernel concreto. `nvidia-smi` confirma que el módulo está cargado, pero `vulkaninfo` y `glxinfo` comprueban que las APIs gráficas pueden usarlo.

`prime-run` lanza un proceso con variables que seleccionan NVIDIA en un portátil híbrido; no obliga a usar NVIDIA para todo Niri. Los paquetes `lib32-` instalan bibliotecas de 32 bits necesarias para Proton y algunos juegos.

## 13 · Recuperación local de Codex

Un JSONL contiene un objeto JSON por línea. `head -n 1 rollout.jsonl | jq -r '.payload.cwd'` toma solo la cabecera y extrae el directorio de trabajo sin comillas JSON. Esto permite seleccionar sesiones del proyecto sin leerlas manualmente.

`sqlite3 base ".backup 'copia.sqlite'" usa la API de respaldo de SQLite, segura para una base activa. `PRAGMA integrity_check` valida estructuras internas. `sha256sum -c manifiesto` comprueba que cada archivo copiado conserva los mismos bytes; no prueba que los datos sean seguros ni sustituye un respaldo.

## 14 · Pantalla de inicio

El greeter se ejecuta como el usuario `greeter`, no como `calli`; por permisos no puede leer directamente tu home. `haku-greeter-sync` copia recursos necesarios a `/var/lib`. La geometría `540x240+690+420` sigue el formato ancho×alto+X+Y de ImageMagick.

`python -c 'import tomllib; …'` ejecuta una instrucción Python que analiza TOML. Si falla, informa sintaxis inválida sin reiniciar greetd. No reinicies greetd desde una sesión gráfica: terminaría el login que estás usando.

## 15 · Rendimiento idle

`free -h` lee contadores globales del kernel; “available” indica memoria recuperable/mejor margen que sumar procesos. `ps -eo … --sort=-rss` define columnas y ordena por RSS descendente. RSS cuenta páginas residentes, incluidas algunas compartidas, por lo que sumarlo sobreestima RAM física.

Una medición idle debe realizarse con la sesión estable y aplicaciones de trabajo cerradas. Compilaciones, descargas, Steam o navegadores invalidan esa comparación.

## 16 · Compilaciones Haku

Meson genera la construcción y Ninja recompila solo objetivos afectados. `meson compile -C build-release` usa un árbol de compilación, no instala en `/usr`. `makepkg -f` genera un paquete desde PKGBUILD y puede sobrescribir el artefacto local anterior.

`pacman -U archivo.pkg.tar.zst` instala un paquete local y registra sus archivos. Subir `pkgrel` reemplaza la revisión anterior de ese paquete; no mantiene varios binarios activos. La configuración de `~/.config` queda fuera del paquete por diseño.

## 17 · Aplicaciones y YTMDesktop

YTMDesktop está como aplicación portátil: `app/` es el programa, `config/` su estado y `themes/` los temas. `Haku Dynamic.css` es salida generada; la fuente editable es `archivo.css`. `haku-ytmd-theme` vuelve a generar la salida cuando `set-wallpaper` actualiza el acento.

MPRIS publica controles y metadatos mediante D-Bus, que Waybar y Haku Media consumen sin leer la ventana de YTMDesktop. No iniciar Electron automáticamente evita elevar el consumo idle.

## Herramienta de estudio

Para inspeccionar cualquier ejemplo con contexto y números de línea:

```console
$ nl -ba ~/.local/bin/sww | sed -n '1,180p'
$ nombre-del-comando --help
$ man nombre-del-comando
```

Lee primero el destino de una orden destructiva con `realpath`, `findmnt`, `ls` o una simulación `--dry-run`/`-n`. Copia el comando, reemplaza las rutas de ejemplo y verifica su resultado antes de pasar al siguiente paso.
