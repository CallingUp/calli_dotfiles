# Copiar, respaldar y sincronizar

## Copia sencilla

```bash
cp archivo archivo.backup
cp -a carpeta carpeta.backup
```

`-a` conserva permisos, fechas, enlaces y estructura. No es ideal para copiar enormes cantidades sin progreso.

## Sincronización con rsync

Vista previa, sin escribir:

```bash
rsync -aHAXvn origen/ destino/
```

Copia real:

```bash
rsync -aHAXv --info=progress2 origen/ destino/
```

La barra final importa:

- `origen/`: copia el contenido.
- `origen`: crea `destino/origen`.

No uses `--delete` hasta comprenderlo: elimina del destino lo que no existe en el origen.

## Respaldo versionado

```bash
mkdir -p ~/backups
cp -a ~/.config/kitty ~/backups/kitty-$(date +%F-%H%M)
```

Para configuraciones pequeñas, un archivo comprimido es cómodo:

```bash
tar -czf ~/backups/config-$(date +%F).tar.gz ~/.config/kitty ~/.config/fish
tar -tzf ~/backups/config-2026-09-01.tar.gz
```

El segundo comando lista el contenido sin extraerlo.

## Verificar una copia

```bash
diff -ru origen destino
sha256sum archivo copia
```

Para árboles grandes:

```bash
rsync -aHAXnc origen/ destino/
```

`-c` compara contenido mediante checksum y puede tardar.

## Qué copiar y qué regenerar

Conviene respaldar:

- Código y repositorios Git con cambios locales.
- Documentos, fotos y grabaciones.
- Configuraciones editadas manualmente.
- Claves SSH, preservando permisos.
- Escenas OBS, perfiles de correo y bases de datos personales.

Normalmente se regenera:

- `node_modules`, `target`, `build`, `.dart_tool`.
- Cachés de navegador y paquetes.
- Imágenes Docker descargables.
- Shader cache de Steam.

## Datos sensibles

Después de copiar SSH:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_* 2>/dev/null
chmod 644 ~/.ssh/*.pub 2>/dev/null
```

Nunca subas `.env`, `auth.json`, claves privadas o bases de contraseñas a Git.

