# Terminal, rutas y ayuda

## Dónde estoy

```bash
pwd
```

`pwd` imprime el directorio de trabajo. Una ruta absoluta comienza por `/`; una ruta relativa se interpreta desde el directorio actual.

```bash
cd /mnt/Linux-Data/FICON/1
cd ..
cd ~
cd -
```

- `..`: directorio padre.
- `~`: tu home, `/home/calli`.
- `cd -`: regresa al directorio anterior.

## Ver archivos

```bash
ls
ls -lah
ls -lah --time-style=long-iso
```

- `-l`: detalles.
- `-a`: incluye archivos ocultos.
- `-h`: tamaños legibles.

Un nombre que comienza por punto, como `.config`, es oculto por convención.

## Entender un comando

```bash
command --help
man command
type command
command -v command
```

Ejemplos:

```bash
man find
type fastfetch
command -v set-wallpaper
```

`type` es especialmente útil en Fish porque indica si un nombre es ejecutable, alias, abreviación o función.

## Componer comandos

```bash
comando1 | comando2
comando1 && comando2
comando1 || comando2
```

- `|` envía la salida de un comando al siguiente.
- `&&` ejecuta el segundo solo si el primero funcionó.
- `||` ejecuta el segundo solo si el primero falló.

## Redirecciones

```bash
comando > archivo
comando >> archivo
comando 2> errores.log
```

`>` reemplaza el archivo. `>>` añade al final. Verifica siempre el destino antes de usarlos.

## Ejercicios seguros

```bash
pwd
ls -lah ~/.config
type guide
command -v steam
man ls
```

