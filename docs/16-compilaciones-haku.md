# Por qué se compiló Haku

No todos los cambios del escritorio requieren compilar. Se compiló únicamente cuando la función solicitada no existía en el programa instalado y hubo que modificar su código fuente.

## Tres tipos de cambio

### Configuración

Archivos CSS, KDL, TOML, JSON y scripts se interpretan al ejecutarse. Normalmente basta con recargar o reiniciar el programa:

```text
~/.config/niri/
~/.config/waybar/
~/.config/noctalia/config.toml
~/.config/kitty/
~/.config/rofi/
~/.config/fish/
~/.local/bin/
```

Ejemplos: colores, tamaños, módulos, keybinds, wallpaper y prompt de Fish. Estos cambios no crean paquetes.

### Compilación de prueba

C++ se transforma en un binario. Durante el desarrollo se recompila para probar cada modificación y detectar errores antes de instalarla:

```console
$ meson compile -C build-release
$ ninja -C build
```

Recompilar no instala otra copia ni acumula versiones activas. Actualiza los archivos del directorio `build`.

### Paquete de Pacman

Cuando una compilación ya funciona, se empaqueta para que Pacman sepa qué versión está instalada, qué archivos le pertenecen y cómo reemplazarla o desinstalarla. Aumentar `pkgrel` reemplaza la revisión anterior; no deja todas las revisiones ejecutándose.

```console
$ makepkg -f
$ sudo pacman -U archivo.pkg.tar.zst
```

## Noctalia Haku

Código fuente:

```text
~/build/noctalia-haku/
```

Paquete:

```text
~/build/noctalia-haku-pkg/
```

Se modificó código nativo para funciones que TOML o los plugins no podían proporcionar:

- anclas externas de paneles abiertos desde Waybar;
- posición estable de paneles flotantes;
- comportamiento del hover entre Waybar y Noctalia;
- menú de sesión compacto, vertical y alineado con su botón.

El paquete activo es `noctalia-haku 5.0.0_beta.10.haku1-7`. Cada `pkgrel` nuevo sustituyó al anterior.

## Waybar Haku

Código fuente:

```text
~/build/waybar-hover/Waybar/
```

Paquete:

```text
~/build/waybar-haku-pkg/
```

Se añadió soporte para ejecutar comandos al entrar y salir con el puntero, exportar las coordenadas del ancla, estabilizar los eventos de los grupos y alinear el área del calendario. El paquete activo es `waybar-haku 0.15.0.haku1-1`; reemplaza al paquete oficial `waybar` y proporciona `/usr/bin/waybar`.

El paquete contiene únicamente el binario, `libcava.so`, el servicio de usuario, la configuración predeterminada y las licencias. Ocupa aproximadamente 3.8 MiB instalado. Las configuraciones personales siguen separadas en `~/.config/waybar/`.

El binario del directorio `build` se conserva como referencia, pero no se ejecuta. Solo hay una instancia activa y utiliza `/usr/bin/waybar`.

## Noctalia Greeter

El código oficial 1.3.0 se clonó en:

```text
~/build/noctalia-greeter-haku/
```

Se estudió su renderizador para evaluar blur nativo. No se instaló una compilación personalizada: el greeter activo sigue siendo el paquete oficial `noctalia-greeter 1.3.0-1`. El efecto final se resolvió generando la imagen desde `haku-greeter-sync`, sin añadir otro paquete.

## Respaldos

Los puntos estables del hover están en:

```text
~/build/haku-checkpoints/
```

Son archivos de respaldo en disco, no procesos ni paquetes instalados. Se conservan para volver a una versión funcional si una modificación futura falla.

## Consultas útiles

```console
$ pacman -Q noctalia-haku waybar-haku noctalia-greeter
$ pacman -Qo /usr/bin/noctalia
$ pacman -Qo /usr/bin/waybar
$ pgrep -a noctalia
$ pgrep -a waybar
```

`pacman -Q` muestra paquetes instalados; `pacman -Qo` indica a qué paquete pertenece un archivo; `pgrep` muestra procesos realmente ejecutándose.
