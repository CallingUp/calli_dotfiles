# Paquetes en CachyOS

CachyOS deriva de Arch Linux y usa `pacman`. `yay` añade soporte cómodo para AUR.

## Consultar sin modificar

```bash
pacman -Q
pacman -Q paquete
pacman -Qs nvidia
pacman -Ss vulkan
pacman -Si paquete
pacman -Qi paquete
```

- `-Q`: base local, lo instalado.
- `-S`: repositorios sincronizados.
- `s`: búsqueda.
- `i`: información.

## Actualizar correctamente

```bash
sudo pacman -Syu
```

En Arch no se recomienda actualizar solo un paquete del sistema ignorando el resto: puede producir una actualización parcial incompatible.

## Instalar y eliminar

```bash
sudo pacman -S paquete
sudo pacman -Rns paquete
```

Antes de eliminar:

```bash
pacman -Qi paquete
pactree -r paquete
```

## Verificar archivos instalados

```bash
pacman -Qkk paquete
pacman -Ql paquete
```

Los avisos de propietario pueden ser falsos dentro de un sandbox. Verifica en la sesión real si parecen afectar a todos los archivos.

## Caché de paquetes

Consultar:

```bash
du -sh /var/cache/pacman/pkg
```

Conservar una versión de cada paquete:

```bash
sudo paccache -rk1
```

Eliminar paquetes desinstalados de la caché:

```bash
sudo paccache -ruk0
```

La caché permite retroceder versiones. No la vacíes completamente sin necesidad.

## AUR

```bash
yay -Ss nombre
yay -Si nombre
yay -S nombre
```

Lee el `PKGBUILD` antes de instalar software del AUR. Para drivers y componentes críticos, prefiere repositorios oficiales.

