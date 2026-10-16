# Bloqueo independiente

[Documentación](../../../docs/README.md) · [Instalación](../../../docs/INSTALL.md)

Vista previa, sin bloqueo ni autenticación:

```sh
~/.local/bin/haku-lock --preview
```

Esc cierra la vista previa. El modo normal usa WlSessionLock y PAM con
`/etc/pam.d/hyprlock`. Solo PamResult.Success libera la sesión; no existe
IPC de desbloqueo.

Prueba real, después de guardar el trabajo (sin otro bloqueo activo):

```sh
~/.local/bin/haku-lock
```

Pulsa una tecla para pasar del reloj a la entrada; escribe la contraseña y
pulsa Enter. No ejecutes la prueba con `timeout` ni mates el proceso: si
el cliente muere, el compositor puede mantener la sesión bloqueada.
`Mod+Ctrl+L` y el menú de bloqueo usan este cliente.
En el perfil avanzado, `Mod+Shift+L` bloquea antes de suspender;
el portable no asigna ese atajo. El bloqueo requiere configurar PAM por separado:
el instalador no genera una política ni activa un bloqueo de prueba.
`--suspend` solo suspende después de confirmar `secure` mediante IPC de
solo lectura. No hay IPC de desbloqueo. Un `--preview` abierto debe cerrarse
antes de ejecutar una prueba real (usan el mismo identificador de configuración).

Diez fallos imponen una espera local de 60 segundos; PAM puede imponer
su propia política adicional. Contraseñas únicamente en memoria, nunca
en argumentos, archivos o registros. El bloqueo corre separado de la barra.
