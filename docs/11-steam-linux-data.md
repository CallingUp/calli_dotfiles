# Steam y biblioteca Extra-Data

## Estado actual

Todas las bibliotecas se consolidaron el 1 de septiembre de 2026 en:

```text
/mnt/Extra-Data/GAMES/SteamLibrary
```

Resultado:

```text
189 GiB aproximados de steamapps
16 manifests instalados
7 juegos
220 GiB libres en Extra-Data al terminar
```

La biblioteca antigua:

```text
/mnt/Linux-Data/SteamLibrary
```

quedó vacía. La biblioteca integrada en `~/.local/share/Steam` conserva su carpeta `steamapps`, pero ya no contiene juegos.

## Juegos detectados

- Hades II
- ELDEN RING
- ELDEN RING NIGHTREIGN
- Balatro
- Geometry Dash
- Quaver
- Dota 2

También se trasladaron Proton, Steam Linux Runtime, Steamworks Common Redistributables, Workshop, shader cache, compatdata y una descarga parcial. `UnlimitedWoW` sigue fuera de Steam.

## Cómo se detectaron

Steam guarda un manifiesto por aplicación:

```bash
find /mnt/Extra-Data/GAMES/SteamLibrary/steamapps -maxdepth 1 -name 'appmanifest_*.acf'
rg '"appid"|"name"|"installdir"|"SizeOnDisk"' appmanifest_1145350.acf
```

## Registro de la biblioteca

Archivo activo:

```text
~/.local/share/Steam/config/libraryfolders.vdf
```

`~/.steam/steam` enlaza a `~/.local/share/Steam`, por lo que ambas rutas aparentes terminan en el mismo archivo real.

La entrada vigente usa:

```text
/mnt/Extra-Data/GAMES/SteamLibrary
```

El respaldo previo a la consolidación está en:

```text
~/backups/steam-libraryfolders-before-extra-20260901-194207/
```

## Cómo se movieron los juegos

Steam estaba cerrado. Se localizaron bibliotecas, manifests y tamaños antes de copiar:

```bash
pgrep -a -f 'steam|steamwebhelper'
find ~/.local/share/Steam /mnt/Linux-Data -name 'appmanifest_*.acf'
du -sh ~/.local/share/Steam/steamapps
du -sh /mnt/Linux-Data/SteamLibrary/steamapps
df -h /mnt/Extra-Data
```

Se creó el destino:

```bash
mkdir -p /mnt/Extra-Data/GAMES/SteamLibrary/steamapps
```

La biblioteca de la raíz se movió primero:

```bash
rsync -aHAX --info=progress2 --remove-source-files \
  ~/.local/share/Steam/steamapps/ \
  /mnt/Extra-Data/GAMES/SteamLibrary/steamapps/
```

Luego Linux-Data se fusionó sin reemplazar archivos existentes:

```bash
rsync -aHAX --ignore-existing --info=progress2 --remove-source-files \
  /mnt/Linux-Data/SteamLibrary/steamapps/ \
  /mnt/Extra-Data/GAMES/SteamLibrary/steamapps/
```

Opciones usadas:

- `-a`: conserva estructura, fechas, permisos y enlaces.
- `-H`: conserva hard links.
- `-A`: conserva ACL.
- `-X`: conserva atributos extendidos.
- `--remove-source-files`: retira cada archivo fuente solo después de copiarlo correctamente.
- `--ignore-existing`: no reemplaza en el destino archivos ya copiados.

Había un runtime Sniper duplicado: 797 MiB en la raíz y solo 4.6 MiB en Linux-Data. Copiar primero la versión completa y usar `--ignore-existing` evitó que la incompleta la reemplazara.

`--remove-source-files` no elimina directorios ni conflictos omitidos. Después de verificar se retiraron únicamente el manifest redundante, cinco enlaces duplicados y directorios vacíos.

## Validación realizada

Para cada manifest se extrajeron `appid`, `name` e `installdir`, comprobando que existiera:

```text
steamapps/common/<installdir>
```

Resultado:

```text
manifests=16
juegos=7
directorios_faltantes=0
referencias_a_rutas_antiguas=0
propietarios_distintos_de_calli=0
```

Los miles de enlaces que `find -xtype l` muestra como rotos pertenecen a Steam Linux Runtime y Pressure Vessel. Muchos apuntan a `/run/host` y solo resuelven dentro del contenedor de Steam; no se eliminaron.

Espacio final:

```text
/                   85 GiB libres
/mnt/Linux-Data     107 GiB libres
/mnt/Extra-Data     220 GiB libres
```

## Procedimiento seguro

1. Cerrar Steam con `steam -shutdown` o confirmar que no haya procesos.
2. Confirmar que terminó.
3. Respaldar ambos VDF.
4. Registrar `/mnt/Extra-Data/GAMES/SteamLibrary`.
5. Abrir Steam.
6. Revisar `content_log.txt`.

Verificación usada:

```bash
tail -200 ~/.local/share/Steam/logs/content_log.txt | rg 'Loaded Steam library|2 libraries|Fully Installed'
```

## Precaución de espacio

Steam necesita espacio adicional para actualizaciones, shader cache y prefijos Proton. Si una biblioteca tiene menos de algunos GB libres, pausa descargas antes de actualizar juegos grandes.
