<div align="center">

# calli_dotfiles

Mis dotfiles y escritorio para **Niri**, construidos con **QuickShell** y helpers **Rust**.

Islas por hover · Wallpapers · Música · Notificaciones · Launcher · Lock

[Instalación](#instalación) · [Atajos](#atajos) · [Documentación](docs/README.md) · [Restauración](#restauración)

</div>

## El escritorio

Tres islas discretas con información y controles al pasar el cursor, paneles
integrados y una paleta siamesa: negro, crema y tonos cálidos.
El bloqueo y el acceso pueden conservar un acento dinámico separado.

- Launcher con búsqueda y aplicaciones frecuentes.
- Carrusel de wallpapers locales y búsqueda en Wallhaven.
- Reproductor MPRIS, notificaciones, clipboard y panel de atajos.
- Audio, brillo, Wi-Fi y Bluetooth.
- Bloqueo propio y helpers Rust con alternativas Python.

La interfaz actual no necesita Waybar, Rofi ni Noctalia. Sus configuraciones
históricas no se activan con el instalador.

## Antes de instalar

> **Instalador en desarrollo.** Revisa la vista previa antes de aplicar.
> Debian/Ubuntu no se han validado en una instalación real; los módulos NixOS
> siguen pendientes de evaluación y compilación.

| Sistema | Método | Condición |
| --- | --- | --- |
| Arch y derivados | Instalador + pacman | Dependencias disponibles en tus repositorios |
| Debian / Ubuntu | Instalador + apt | Niri, QuickShell y Qt compatibles disponibles |
| NixOS | NixOS + Home Manager | Integración declarativa experimental |

Requisitos: Linux con systemd de usuario, Niri reciente, QuickShell 0.3.x
compatible con **Qt >= 6.9**, Git y Python 3.9+. Rust/Cargo reciente solo es
necesario para compilar los helpers; de lo contrario se usan alternativas Python.

No basta con tener QuickShell: su Qt también debe ser compatible. El instalador
no añade AUR, PPA ni backports. Lee los [requisitos por distribución](docs/INSTALL.md#estado-y-límites).

## Instalación

### 1. Clonar

Ejecuta como tu usuario, **sin sudo**. Si ya existe `~/haku_shell`, revisa
ese checkout antes de continuar; no lo sobrescribas.

```sh
git clone --branch feature/minflair-niri-port https://github.com/CallingUp/haku_shell.git ~/haku_shell
cd ~/haku_shell
```

### 2. Revisar el plan

```sh
./install.sh --dry-run --dependencies --build --apps --keyboard latam
```

La vista previa no instala paquetes ni copia configuraciones. Sustituye
`latam` por tu teclado, por ejemplo `es` o `us`.

### 3. Aplicar

```sh
./install.sh --apply --dependencies --build --apps --enable --keyboard latam
```

El gestor de paquetes solicita sudo y confirmación cuando corresponde.
El instalador valida Niri y respalda individualmente los archivos reemplazados.

| Opción | Función |
| --- | --- |
| `--apply` | Aplica cambios; sin ella solo muestra el plan |
| `--dependencies` | Instala dependencias de los repositorios configurados |
| `--build` | Compila los cinco helpers Rust |
| `--apps` | Incluye Kitty, Alacritty, GTK 3/4 y Qt 5/6 |
| `--enable` | Habilita el servicio para sesiones posteriores, sin arrancarlo ahora |
| `--keyboard latam` | Teclado del perfil portable |
| `--profile portable` | Perfil predeterminado, sin hardware personal |

Si ya tienes las dependencias y no quieres compilar ni cambiar aplicaciones:

```sh
./install.sh --apply --enable --keyboard latam
```

El perfil opcional `personal` necesita el fork SHORiN y conserva ajustes
específicos del equipo original. Para otro equipo usa el portable.
Consulta [las diferencias entre perfiles](docs/INSTALL.md#perfiles-de-niri).

### 4. Primera sesión

1. Guarda tu trabajo e inicia una sesión Niri desde tu gestor de acceso.
2. Añade imágenes a `~/Pictures/Wallpapers` y abre el carrusel con `Mod + ,`.
3. Comprueba launcher, audio, red y notificaciones.
4. Prueba primero el bloqueo en vista previa:

```sh
~/.local/bin/haku-lock --preview
```

**El bloqueo real requiere un servicio PAM válido en `/etc/pam.d/hyprlock`.**
El instalador no lo crea ni cambia contraseñas. Consulta
[primera sesión y seguridad](docs/INSTALL.md#primera-sesión-y-seguridad).

No muevas ni borres el checkout: la shell carga componentes desde
`~/haku_shell`. PipeWire/WirePlumber, NetworkManager y Bluetooth deben estar
configurados por tu distribución. Evita ejecutar dos servidores de
notificaciones simultáneamente.

### NixOS

No uses `./install.sh --apply`. Clona en una ruta como `~/src/haku_shell`:
Home Manager administra `~/haku_shell` como enlace al store.

La flake exporta `nixosModules.default`, `homeManagerModules.default` y los
helpers para `x86_64-linux` / `aarch64-linux`.
Sigue la [guía NixOS y Home Manager](docs/INSTALL.md#nixos-y-home-manager)
para importar módulos, revisar servicios y fijar nixpkgs. Esta ruta todavía
necesita validación real.

## Alcance de la instalación

Se despliegan el perfil Niri, scripts permitidos, paleta y servicio de usuario.
Las configuraciones de aplicaciones mencionadas arriba son opcionales.

No se modifica automáticamente:

- Drivers, discos, energía, SSH ni shell de login.
- SDDM, su tema o políticas PAM.
- Perfiles Zen, Vesktop, Neovim ni configuración del prompt.
- El fork personal de Niri ni repositorios adicionales.

No se incluyen wallpapers, fuentes personales, cookies, claves, juegos,
cachés ni binarios compilados. El gestor integrado de paquetes requiere Arch
y `yay`; se deshabilita cuando ese backend no está disponible.

## Atajos

Del **perfil portable**. `Mod` normalmente es Super/Windows.

| Atajo | Acción |
| --- | --- |
| `Mod + Enter` | Launcher |
| `Mod + T` | Terminal Kitty |
| `Mod + O` | Overview |
| `Mod + ,` | Carrusel de wallpapers |
| `Mod + .` | Reproductor y notificaciones |
| `Mod + N` | Controles de conectividad |
| `Mod + V` | Clipboard |
| `Mod + Ctrl + L` | Bloquear, después de configurar PAM |
| `Mod + ← / →` | Alternar acceso a las islas |
| `Mod + ↑ / ↓` | Ocultar / mostrar la barra |
| `Mod + H / J / K / L` | Mover el foco |
| `Mod + Q` | Cerrar ventana |

El portable no replica los shaders, grid overview ni todas las funciones del
fork personal. Las transiciones de wallpaper usan fade de awww/swww.

## Restauración

Los respaldos están en `~/.local/state/haku-installer/backups/`.
Sustituye `FECHA` por el directorio mostrado al instalar:

```sh
# Revisar
./install.sh --restore ~/.local/state/haku-installer/backups/FECHA

# Aplicar
./install.sh --restore ~/.local/state/haku-installer/backups/FECHA --apply
systemctl --user daemon-reload
```

La restauración protege archivos editados después de instalar y señala
conflictos. No desinstala paquetes ni deshabilita el servicio automáticamente.
Consulta [los límites de restauración](docs/INSTALL.md#restaurar-configuraciones).

## Documentación y estructura

| Ruta | Contenido |
| --- | --- |
| [docs/INSTALL.md](docs/INSTALL.md) | Instalación detallada, seguridad, NixOS y pruebas |
| [docs/README.md](docs/README.md) | Índice de guías públicas |
| `config/` | Configuraciones y componentes QML |
| `scripts/bin/` | Comandos y wrappers |
| `tools/` | Helpers Rust y pruebas |
| `installer/` | Instalador y perfil portable |
| `nix/` | NixOS / Home Manager |
| `optional/`, `patches/` | Material histórico; no se instala automáticamente |

## Créditos

Este escritorio parte de [Hakuspace](https://github.com/hakuimaku/hakuspace).
La interfaz QuickShell incorpora y adapta código de
[Minflair](https://github.com/t4lentles5/minflair) para Niri.
Consulta la [atribución del port](config/quickshell/minflair-niri/PORT.md)
y la licencia incluida con ese código.
