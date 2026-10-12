# Bloqueo independiente

Vista previa, sin bloqueo ni autenticación:

```sh
HAKU_LOCK_PREVIEW=1 quickshell -p ~/haku_shell/config/quickshell/haku-lock/shell.qml
```

Esc cierra la vista previa. El modo normal usa WlSessionLock y PAM con
`/etc/pam.d/hyprlock`. Solo PamResult.Success libera la sesión; no existe
IPC de desbloqueo. Autenticación real validada por el usuario el 2026-10-11.

Prueba real, después de guardar el trabajo (sin otro bloqueo activo):

```sh
bash ~/haku_shell/scripts/bin/haku-lock
```

Pulsa una tecla para pasar del reloj a la entrada; escribe la contraseña y
pulsa Enter. No ejecutes la prueba con `timeout` ni mates el proceso: si
el cliente muere, el compositor puede mantener la sesión bloqueada.
`Mod+Ctrl+L` y el menú de bloqueo usan este cliente.
`Mod+Shift+L` bloquea antes de suspender.
`--suspend` solo suspende después de confirmar `secure` mediante IPC de
solo lectura. No hay IPC de desbloqueo. Un `--preview` abierto debe cerrarse
antes de ejecutar una prueba real (usan el mismo identificador de configuración).

Diez fallos imponen una espera local de 60 segundos; PAM puede imponer
su propia política adicional. Contraseñas únicamente en memoria, nunca
en argumentos, archivos o registros. El bloqueo corre separado de la barra.
