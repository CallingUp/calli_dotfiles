# Discos, particiones y montajes

## Inventario de discos

```bash
lsblk -o NAME,FSTYPE,LABEL,UUID,SIZE,FSAVAIL,MOUNTPOINTS
blkid
df -hT
findmnt
```

- `lsblk`: estructura física y particiones.
- `df`: espacio disponible en sistemas montados.
- `findmnt`: origen, destino y opciones reales.
- UUID: identificador estable, preferible a `/dev/nvme0n1p7`.

## Montaje temporal de solo lectura

```bash
udisksctl mount -b /dev/nvme1n1p3 --options ro
udisksctl unmount -b /dev/nvme1n1p3
```

Se usó para auditar Pop!_OS sin modificarlo.

La auditoría también mostró por qué un desmontaje puede fallar:

```bash
fuser -vm /ruta/del/montaje
lsof +f -- /ruta/del/montaje
```

En este caso Nautilus mantenía abierto `Downloads` dentro de Pop!_OS. Se cerró limpiamente antes de continuar:

```bash
nautilus -q
```

No se usó `umount -f` ni se forzó el reparticionado con el disco ocupado.

## Montaje permanente

La biblioteca `Linux-Data` se añadió a `/etc/fstab` con:

```fstab
UUID=3cb2c7de-e7ca-4068-902a-5bbe254541de /mnt/Linux-Data ext4 defaults,noatime,nofail,x-systemd.automount,x-systemd.device-timeout=5s 0 2
```

- `noatime`: evita escrituras de acceso innecesarias.
- `nofail`: el arranque continúa si falta el disco.
- `x-systemd.automount`: monta al acceder.
- `device-timeout=5s`: limita la espera.

El nuevo volumen `Extra-Data` quedó registrado con:

```fstab
UUID=09cd7371-585f-4966-bf3b-1528197bb2c6 /mnt/Extra-Data ext4 defaults,noatime,nofail,x-systemd.automount,x-systemd.device-timeout=5s 0 2
```

Estado final de los discos de datos:

```text
/mnt/Linux-Data  → /dev/nvme0n1p7
/mnt/Extra-Data  → /dev/nvme1n1p1
```

## Eliminación de Pop!_OS y creación de Extra-Data

Esta operación se realizó el 1 de septiembre de 2026 sobre el disco completo:

```text
/dev/nvme1n1
Modelo: WD Green SN350 500GB 2G0C
Tamaño exacto: 500107862016 bytes
```

Diseño anterior:

```text
1 GiB       EFI de Pop!_OS
8 GiB       swap de Pop!_OS
456.8 GiB   sistema ext4 de Pop!_OS
```

Diseño final:

```text
415.8 GiB   /dev/nvme1n1p1, ext4, etiqueta Extra-Data
50.0 GiB    sin asignar para una distro de pruebas
```

Capacidad presentada por el sistema de archivos:

```text
409 GiB utilizables en /mnt/Extra-Data
```

### Verificaciones antes de borrar

El script comprobó de forma estricta:

```bash
lsblk -bdno SIZE /dev/nvme1n1
lsblk -dno MODEL /dev/nvme1n1
findmnt -nro SOURCE /
lsblk -no PKNAME "$(findmnt -nro SOURCE /)"
```

Solo continuaba si tamaño y modelo coincidían y `/` no pertenecía a `nvme1n1`. Esto evita depender únicamente del nombre del dispositivo.

También se desmontó cada partición hija y se desactivó su swap:

```bash
findmnt -rn -S /dev/nvme1n1p3 -o TARGET
sudo umount /run/media/calli/5f34a217-91f8-4e79-97d8-747ac047e9df
sudo swapoff /dev/nvme1n1p2
```

### Reparticionado destructivo

Advertencia: los siguientes conceptos destruyen la tabla y los datos del disco objetivo. No reutilices los números sin recalcularlos para el dispositivo real.

El disco tiene sectores de 512 bytes. Para dejar exactamente 50 GiB:

```text
50 × 1024³ ÷ 512 = 104857600 sectores
```

Se creó una tabla GPT y una partición desde el sector 2048 hasta dejar esos sectores libres al final. La ejecución automatizada está guardada en:

```text
~/.local/bin/repartition-pop-disk
```

Después se creó ext4 sin reserva porcentual para root, porque es un volumen de datos:

```bash
sudo mkfs.ext4 -F -m 0 -L Extra-Data /dev/nvme1n1p1
```

`-m 0` evita reservar 5 % para root. No suele usarse en `/`, pero resulta apropiado para un volumen dedicado a datos.

### Montaje e integración

El instalador usado quedó en:

```text
~/.local/bin/install-extra-data-mount
```

Operaciones relevantes:

```bash
sudo mkdir -p /mnt/Extra-Data
sudo mount /mnt/Extra-Data
sudo chown calli:calli /mnt/Extra-Data
findmnt --verify
sudo systemctl daemon-reload
findmnt /mnt/Extra-Data
df -hT /mnt/Extra-Data
```

El respaldo anterior de `fstab` está en:

```text
~/backups/fstab-before-extra-data-20260901-1922/fstab
```

La comprobación final con `parted` confirmó:

```text
Partición Extra-Data: 416 GiB mostrados
Free Space final:     50.0 GiB
```

## Procedimiento seguro para fstab

```bash
sudo cp -a /etc/fstab /etc/fstab.backup
sudo mkdir -p /mnt/Linux-Data
sudo nano /etc/fstab
findmnt --verify
sudo systemctl daemon-reload
sudo mount /mnt/Linux-Data
findmnt /mnt/Linux-Data
```

Mantén una terminal abierta mientras pruebas. Un `fstab` inválido puede complicar el siguiente arranque.

## Medir espacio

```bash
df -h /
df -h /mnt/Linux-Data
df -h /mnt/Extra-Data
du -sh /mnt/Linux-Data/SteamLibrary
```

`df` mide el sistema de archivos completo; `du` mide carpetas.
