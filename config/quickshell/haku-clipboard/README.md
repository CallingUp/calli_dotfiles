# Portapapeles QML

`Mod+Shift+V`, `cliphist.sh`, `clipboard_menu.sh` y `haku-clipboard` abren la
misma vista. Usa el historial existente de cliphist, sin migrar ni borrar datos.
No añade servicios en segundo plano ni sondeo periódico.

- Búsqueda y filtros: todo, texto, imágenes y enlaces.
- Flechas para seleccionar, Enter/botón/doble clic para copiar.
- Vista previa al seleccionar: texto plano (hasta 64 Ki caracteres) o imagen
  limitada a 800px de carga visual. Decode máximo 16 MiB para la vista previa.
- Alt+Supr o × borra solo la entrada seleccionada; Vaciar pide confirmación.
- Ctrl+R actualiza el historial; Esc/clic fuera cierra.

La copia no tiene el límite de la vista previa y conserva los bytes originales,
incluidas imágenes y texto multilínea. No se pega ni se escribe automáticamente
en la aplicación que tenía el foco. Ningún contenido se interpola en comandos
shell. Los IDs se validan como enteros decimales.

Los previews se guardan en el directorio temporal privado del selector,
desaparecen al cerrar normalmente y no se guardan en un caché compartido.
La búsqueda se hace sobre el resumen de cliphist, no sobre todo el contenido.
Las previews se decodifican bajo demanda tras 100ms, nunca todo el historial.

Pruebas (mock; no copian ni borran datos reales):

```sh
python3 ~/haku_shell/config/quickshell/haku-clipboard/test_clipboard.py
```
