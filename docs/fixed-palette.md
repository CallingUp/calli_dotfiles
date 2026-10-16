# Haku Siamese: paleta fija

Fuente activa: `~/.config/haku/palette.conf`.
Copia distribuida: `config/haku/palette.conf`.

Negro #000000, texto crema #E8DCC8, acento café #B99573,
selección/foco claro #D7B894, café oscuro #705542.

QuickShell observa ese archivo y no carga esquemas antiguos ni ejecuta sus
aplicadores dinámicos en modo fijo. Cambiar wallpaper no extrae colores:
`set-wallpaper` lee los acentos de esa paleta. El renderizado y las animaciones
del wallpaper no se alteran. Los archivos generados para otros consumidores
siguen siendo compatibles con sus formatos anteriores.

GTK 3/4 importan `~/.config/haku/palette.css` (derivada de palette.conf).
Qt 5/6 usan `colors/haku-siamese.conf` con estilo Fusion y paleta personalizada.
Se conservan fuentes, iconos y cursores existentes. Los archivos CSS/Qt son
salidas derivadas: su regeneración unificada aún está pendiente, no son
consumidores directos del archivo shell. Los programas abiertos pueden requerir
reapertura. Aplicaciones con estilos propios/Flatpak pueden no seguir estas
preferencias; no se promete cobertura universal.

Kitty y Alacritty comparten colores ANSI, selección y cursor. El generador de
Kitty en set-wallpaper conserva esos colores al cambiar fondo. Neovim lee la
paleta central una vez por aplicación del tema, sin modificar plugins ni teclas.
Zsh usa su prompt propio actualmente: haku-theme.zsh lee la paleta con builtins
y actualiza resaltado/prompt sin ejecutar sed/head en cada prompt. El archivo
Oh My Posh también queda adaptado, pero no se cambia el motor del prompt.

Vesktop conserva System24; su generador lee palette.conf directamente y el
QuickCSS activo fue regenerado. Sigue importando System24 remoto como antes.
Zen usa `chrome/haku-siamese.css` mediante userChrome.css en el perfil elegido,
con estilos de interfaz, sin userContent.css ni modificaciones a páginas web.
Se conservan zen-themes.css y los mods. Reinicia Zen para cargar user.js y
userChrome.css. Sus colores CSS aún son una salida estática.

Excepción solicitada: SDDM y lock conservan el acento dinámico. El sincronizador
de SDDM extrae un acento del wallpaper normalizado y lo guarda en su configuración
y en `~/.local/state/haku_theme/login-colors.css`. El lock lee ese archivo,
independiente de colors.css y de la paleta fija del escritorio. No se modifica
PAM, la política de intentos ni el bloqueo de sesión. El wallpaper sigue dinámico.

Pendiente: regeneración conjunta de salidas estáticas y comprobación visual de
aplicaciones tras reiniciarlas.
Steam queda fuera de la tematización: Millennium no es un requisito ni se instala.
No se considera terminada la
unificación de todas las aplicaciones por centralizar la shell.
