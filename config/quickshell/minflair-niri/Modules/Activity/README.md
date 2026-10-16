# Panel derecho de actividad

[Documentación](../../../../../docs/README.md) · [Instalación](../../../../../docs/INSTALL.md)

Integra `MiniMusicWidget` y `NotificationCenter` de Minflair en una superficie
pegada al borde derecho, con la paleta compartida de la shell. Reutiliza MPRIS
y la única instancia de NotificationService; no inicia otro daemon.

- `Mod+.` en el perfil portable alterna abrir/cerrar.
- Clic en el acceso de música o clic derecho en el reloj: abrir/cerrar.
- Escape, clic fuera u ocultar la barra: cerrar.
- Pantalla completa: se oculta junto con la barra.
- IPC: `quickshell ipc -p ~/haku_shell/config/quickshell/minflair-niri/niri-preview.qml call haku-activity toggle`.

Entrada de 160 ms y salida de 90 ms. El reproductor y las notificaciones se
cargan únicamente mientras el panel está visible.

## Pulido

- Carátula de hasta 144 px, sin cambiar el reproductor compacto reutilizado en otros sitios.
- Historial agrupado visualmente por aplicación: conserva mensajes y acciones individuales.
- Clic en la tarjeta expande; × elimina. Las acciones que envía la aplicación
  aparecen únicamente al expandir y sólo mientras la notificación siga disponible.
- Concentración automática con Game Mode o capturas detectadas por los eventos
  `CastsChanged`, `CastStartedOrChanged` y `CastStopped` de Niri. Conserva el
  historial y no modifica el ajuste manual de No molestar. Las alertas críticas
  mantienen la excepción de urgencia existente.
- Menús genéricos y clipboard comparten radio exterior de 22 px y entrada
  OutCubic de 160 ms con los paneles laterales. El morph del launcher se conserva.
- El carrusel ya incluye contador, marca ACTUAL y precarga de siete tarjetas;
  se conserva su comportamiento y no se inicia una segunda caché.
