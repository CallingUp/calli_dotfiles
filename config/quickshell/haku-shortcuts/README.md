# Panel de atajos

[Documentación](../../../docs/README.md) · [Instalación](../../../docs/INSTALL.md)

`scripts/bin/haku-shortcuts` alterna el componente bajo demanda en la shell
principal. La UI está en `../minflair-niri/Modules/Shortcuts/Shortcuts.qml`.
El helper Rust `tools/haku-info` vuelve a leer los bindings actuales al abrir;
`shortcuts.py` se conserva como alternativa si falta el binario. No hay consultas
periódicas ni proceso auxiliar residente. `shell.qml` conserva el modo separado
si la shell principal no está disponible. Esc y clic fuera cierran el panel.

El panel obtiene los atajos de tu configuración Niri activa; no asume una lista
idéntica entre perfiles. El perfil avanzado incluye `Mod+apostrophe`; el portable
no lo asigna y permite abrirlo con `haku-shortcuts` desde una terminal.
