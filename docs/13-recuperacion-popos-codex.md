# Auditoría de Pop!_OS y recuperación de Codex

## Estado de la recuperación

La recuperación local de FICON terminó el 1 de septiembre de 2026:

- 37 conversaciones añadidas a la instalación actual.
- 37 rollouts JSONL copiados, 117.9 MiB en total.
- Rutas internas actualizadas a `/mnt/Linux-Data/FICON/1`.
- Ninguna conversación actual fue reemplazada.
- No se copiaron credenciales de la cuenta anterior.
- Todos los archivos referenciados existen.
- Los 37 hashes SHA-256 coinciden.
- `PRAGMA integrity_check` devolvió `ok`.

El respaldo previo, el manifiesto y el resumen de esta ejecución están en:

```text
/home/calli/backups/codex-ficon-20260901-183515/
```

El importador reutilizable está en:

```text
/home/calli/.local/bin/import-ficon-codex-sessions
```

## Método de auditoría

Pop!_OS se montó temporalmente en modo solo lectura:

```bash
udisksctl mount -b /dev/nvme1n1p3 --options ro
```

Al terminar:

```bash
udisksctl unmount -b /dev/nvme1n1p3
```

Esto permitió inventariar sin alterar la instalación.

## Datos importantes encontrados

- 37 sesiones de Codex relacionadas con FICON.
- 117.9 MiB de rollouts JSONL.
- Proyecto FICON en `/mnt/Linux-Data/FICON/1`.
- VS Code: configuración y extensiones.
- OBS: perfiles, escenas y grabaciones.
- Brave y Helium: perfiles de navegador.
- Thunderbird: perfil de correo.
- Bottles y FL Studio.
- LibreOffice, VLC, MPV, SSH, Git y Docker.
- Documentos, wallpapers, capturas, música y videos.

## Cómo se encontraron las sesiones

Cada rollout comienza con metadatos que contienen su directorio de trabajo:

```bash
find ~/.codex/sessions -type f -name '*.jsonl'
rg -l '"cwd":"/mnt/linux-data/FICON/1"' ~/.codex/sessions
```

El estado adicional vive en:

```text
~/.codex/state_5.sqlite
~/.codex/session_index.jsonl
~/.codex/attachments/
```

## Por qué no copiar todo `.codex`

La instalación actual ya contiene conversaciones y una base SQLite activa. Reemplazarla perdería o dañaría el historial nuevo. La migración correcta debe:

1. Respaldar el estado actual.
2. Copiar solo los rollouts FICON.
3. Copiar adjuntos referenciados.
4. Fusionar el índice sin IDs duplicados.
5. Importar las filas SQLite correspondientes con Codex cerrado.
6. Corregir el cambio de ruta `linux-data` → `Linux-Data`.
7. Validar una conversación con `codex resume UUID`.

La documentación pública de OpenAI no describe actualmente una importación manual de sesiones locales ni una transferencia de conversaciones Codex entre cuentas Plus. Esta recuperación funciona sobre el almacenamiento local de Codex; no importa los chats al historial web de ChatGPT.

## Comandos usados en la recuperación

El importador realizó estas operaciones de forma automatizada:

```bash
# Copia consistente de la base actual antes de modificarla
sqlite3 ~/.codex/state_5.sqlite ".backup '/ruta/al/respaldo.sqlite'"

# Detección de rollouts y lectura del cwd de cada sesión
find /ruta/popos/home/calli/.codex/sessions -type f -name 'rollout-*.jsonl'
head -n 1 rollout.jsonl | jq -r '.payload.cwd'

# Verificación de la base después de fusionar las 37 filas
sqlite3 ~/.codex/state_5.sqlite 'PRAGMA integrity_check;'

# Verificación criptográfica de los archivos copiados
sha256sum -c imported-rollouts.sha256
```

Para repetir la importación desde la partición Pop!_OS:

```bash
~/.local/bin/import-ficon-codex-sessions
```

El programa es idempotente: conserva archivos e IDs que ya existen en el destino.

## Abrir los chats recuperados

Desde el proyecto:

```bash
cd /mnt/Linux-Data/FICON/1
codex resume --all
```

También se puede abrir una conversación concreta usando el UUID mostrado por Codex:

```bash
codex resume UUID
```

`--all` es importante si la interfaz está filtrando sesiones por el directorio actual.

## Trasladar a otra cuenta Plus

### Lo que sí se puede conservar

- Los rollouts JSONL con el diálogo y las acciones.
- Sus IDs, fechas, títulos y metadatos locales.
- Los adjuntos locales disponibles.
- La capacidad de intentar `codex resume UUID` en la aplicación Codex local.

### Lo que no está garantizado

- Que las conversaciones aparezcan en el historial web de ChatGPT.
- Que una cuenta diferente reconozca como propios los chats locales.
- Que versiones futuras de Codex mantengan el mismo esquema SQLite.
- Que pueda reanudarse un chat que dependía de un modelo o permiso no disponible en la cuenta destino.

No encontré un procedimiento público oficial de OpenAI para importar estas sesiones entre cuentas. Por eso el traslado debe considerarse una migración local compatible, no una transferencia oficial del historial de cuenta.

### Misma computadora, otra cuenta

1. Conserva el respaldo indicado arriba.
2. Cierra Codex completamente.
3. Cierra sesión e inicia sesión con la otra cuenta Plus mediante el flujo normal de Codex.
4. No reemplaces `~/.codex/auth.json` con el de Pop!_OS.
5. Conserva los rollouts y la base ya fusionada en esta computadora.
6. Abre `/mnt/Linux-Data/FICON/1` y prueba `codex resume --all`.

Cambiar la autenticación no debería requerir volver a copiar los rollouts locales, pero esta conducta no está documentada oficialmente. Mantén el respaldo hasta comprobar varias conversaciones.

### Otra computadora y otra cuenta

En un disco externo crea primero un paquete de recuperación. Sustituye `/ruta/del/disco` por una ruta verificada:

```bash
mkdir -p /ruta/del/disco/ficon-codex-recovery
cp -a ~/.local/bin/import-ficon-codex-sessions /ruta/del/disco/ficon-codex-recovery/
cp -a /home/calli/backups/codex-ficon-20260901-183515 \
  /ruta/del/disco/ficon-codex-recovery/respaldo
```

Los rollouts activos están bajo `~/.codex/sessions/2026/08/`. Para copiar solo los 37 correctos usa el manifiesto, no toda la carpeta `.codex`. Una forma segura es conservar las rutas con `rsync`:

```bash
cd /
awk '{print $2}' /home/calli/backups/codex-ficon-20260901-183515/imported-rollouts.sha256 \
  | rsync -aR --files-from=- / /ruta/del/disco/ficon-codex-recovery/rollouts/
```

Después:

1. Instala Codex e inicia sesión normalmente con la cuenta Plus destino.
2. Copia o clona FICON en la ruta deseada.
3. Cierra Codex.
4. Haz un respaldo de `~/.codex` en la computadora destino.
5. Ejecuta el importador pasando cuatro argumentos: `.codex` fuente, `.codex` destino, ruta antigua del proyecto y ruta nueva.
6. Verifica la base y abre `codex resume --all`.

El importador espera una fuente con `state_5.sqlite` además de los rollouts. El respaldo de recuperación conserva una copia consistente de esa base. Antes de usarla en otra computadora, revisa el script y adapta `backup_dir`, que actualmente apunta a `/home/calli/backups`.

## Seguridad de cuenta

Nunca transfieras estos elementos a otra persona o cuenta:

```text
~/.codex/auth.json
tokens
sockets
locks
credenciales dentro de .env
```

La nueva cuenta debe iniciar sesión por su propio flujo de autenticación. Los chats pueden contener código, rutas, prompts o secretos impresos durante el desarrollo; el paquete debe almacenarse cifrado o en un disco personal.

## Qué no migrar automáticamente

- `auth.json` antiguo.
- Sockets IPC y locks.
- Cachés de plugins.
- Snapshots de shell innecesarios.
- Bases SQLite completas sobre las actuales.

## Archivos sensibles de FICON

El proyecto contiene `.env` y una carpeta `secrets`. Deben conservarse, pero nunca imprimirse en logs, compartirse en chats públicos ni añadirse a Git.

## Restricción de espacio

Antes de copiar, ejecuta:

```bash
df -h / /mnt/Linux-Data
```

No migres los 17 GB de Descargas ni perfiles completos de navegador hasta liberar espacio. Prioriza código, sesiones Codex, documentos y claves pequeñas.

Al terminar esta recuperación quedaron aproximadamente 2.0 GiB libres en la raíz. No crees otro paquete local de 118 MiB: escríbelo directamente en `/mnt/Linux-Data` o en un disco externo.
