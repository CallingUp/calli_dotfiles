# Permisos, procesos y servicios

## Leer permisos

```bash
ls -l archivo
stat archivo
id
```

Ejemplo:

```text
-rw-r--r-- calli calli archivo
```

Los tres grupos de bits corresponden a propietario, grupo y otros: lectura `r`, escritura `w`, ejecución `x`.

## Cambiar permisos

```bash
chmod 600 archivo-secreto
chmod 755 script
chmod +x script
```

Cambiar propietario requiere privilegios:

```bash
sudo chown calli:calli archivo
```

No uses `chmod 777` como solución genérica.

## Procesos

```bash
pgrep -a steam
ps aux | rg steam
top
btop
```

Finalización normal:

```bash
pkill programa
```

`SIGKILL` (`kill -9`) debe ser el último recurso porque no permite guardar estado.

## Servicios de usuario y sistema

```bash
systemctl status servicio
systemctl --user status servicio
systemctl list-units --failed
systemctl --user list-units --failed
```

Operaciones comunes:

```bash
sudo systemctl enable --now servicio
systemctl --user restart servicio
```

## Importante sobre entornos aislados

Un sandbox puede mostrar procesos, dispositivos o montajes diferentes a los de la sesión real. Durante la auditoría, Steam y `/dev/nvidia*` no aparecieron dentro del aislamiento aunque funcionaban fuera. Cuando dos fuentes discrepan, verifica desde la sesión real antes de diagnosticar un fallo.

