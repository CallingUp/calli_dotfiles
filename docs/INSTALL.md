# Instalación multiplataforma

## Estado y límites

Primera implementación, no certificada en todas las distribuciones. Probada
localmente: vista previa, despliegue/restauración en directorios temporales,
validación KDL con Niri y pruebas QML. Debian/Ubuntu no se han instalado en VM;
NixOS todavía necesita evaluación/build real porque el equipo de desarrollo
no tiene Nix. No presentar estos módulos como probados en producción.

Requisitos: Linux, sesión Niri reciente, QuickShell 0.3.x compatible con su Qt,
**Qt >= 6.9**, Python 3.9+ para el instalador y systemd de usuario. Los helpers
Rust requieren un Cargo/Rust reciente capaz de consumir los Cargo.lock incluidos.
No se exige Rust para usar los fallbacks Python. Las fuentes e iconos personales
no se descargan ni se redistribuyen; sin ellos se usa el fallback del sistema.

| Sistema | Ruta | Condición |
| --- | --- | --- |
| Arch y derivados | pacman + instalador | paquetes disponibles en repositorios configurados |
| Debian | apt + instalador | Niri, QuickShell y Qt >= 6.9 disponibles en repositorios configurados |
| Ubuntu | apt + instalador | mismas condiciones; puede necesitar un PPA revisado por el usuario |
| NixOS | módulos NixOS + Home Manager | nixpkgs reciente, módulos todavía pendientes de prueba real |

Debian 13 incluye una base Qt 6.8: instalar QuickShell desde backports **no**
garantiza poder ejecutar esta shell. No se actualiza Qt ni se mezcla stable/sid
automáticamente. Ubuntu 24.04 también necesita una pila Qt más reciente que su
base. Usa una versión/repositorio coherente de Qt y QuickShell, no binarios
aleatorios. El instalador se detiene si faltan candidatos o si Qt es antiguo.

Referencias: [QuickShell](https://quickshell.org/docs/v0.3.2/guide/install-setup/),
[Niri](https://github.com/niri-wm/niri/wiki/Getting-Started),
[RectangularShadow desde Qt 6.9](https://www.qt.io/blog/rectangularshadow-fast-rectangle-shadows-in-qt-6.9).
El PPA de Ubuntu indicado por QuickShell es externo; el instalador no lo añade.

## Arch, Debian y Ubuntu

Clona en tu usuario (no con sudo):

```sh
git clone --branch main https://github.com/CallingUp/calli_dotfiles.git ~/haku_shell
cd ~/haku_shell
./install.sh --dry-run --dependencies --apps --build --keyboard latam
```

Revisa el plan. Para instalar paquetes, compilar los cinco helpers e instalar
configuraciones opcionales de aplicaciones:

```sh
./install.sh --apply --dependencies --build --apps --enable --keyboard latam
```

El gestor de paquetes pide confirmación y sudo por su cuenta. No se ejecuta
`pacman -Sy`, no se añade AUR/PPA, no se hace `curl | sh`, no se instalan
controladores ni se modifica la política de energía. Actualiza los índices/
sistema según las recomendaciones de tu distribución antes de instalar.

Si ya tienes dependencias:

```sh
./install.sh --apply --apps --enable --keyboard latam
```

Sin `--apps` solo se instalan shell, scripts permitidos, paleta, servicio y
configuración Niri. Con `--apps` se copian configuraciones Kitty, Alacritty,
GTK 3/4 y Qt 5/6. No se sobrescriben perfiles Zen, Vesktop, Neovim, prompt,
SDDM ni la shell de login: sus temas se entregan en `config/` para integración
manual, porque el repositorio no contiene todas sus configuraciones/plugin
managers y cada equipo usa perfiles diferentes.

Los archivos reemplazados se guardan individualmente en:
`~/.local/state/haku-installer/backups/<fecha>/`. No se copia todo el HOME.
Se conserva un manifiesto con hashes. Directorios de destino enlazados fuera
del HOME y archivos symlink se rechazan para no modificar el checkout u otra
instalación accidentalmente. Las opciones aplicadas son idempotentes a nivel
de archivos; una nueva ejecución puede crear un manifiesto vacío.

`~/haku_shell` debe ser este checkout. Si clonaste en otro lugar se crea un
alias a él, pero nunca se reemplaza otro checkout existente. No muevas ni
borres el checkout después: la shell carga QML y fallbacks desde allí.

## Perfiles de Niri

- `--profile portable` (predeterminado): sin monitor fijo, sin SSH/keyring
  personales, sin lupa/grid overview del fork. Conserva launcher, carrusel,
  clipboard, controles, reproductor, notificaciones y las tres islas hover.
- `--profile personal`: copia tus KDL actuales, con las rutas del nuevo usuario.
  Necesita tu fork [SHORiN](https://github.com/SHORiN-KiWATA/niri); no se compila
  ni instala automáticamente. Conserva monitor/teclado/acciones personales;
  revísalos. El instalador valida antes de reemplazar archivos.

El perfil portable usa Mod+T para terminal, Mod+Enter launcher, Mod+O overview,
Mod+, carrusel, Mod+. actividad, Mod+N controles, Mod+V clipboard y Mod+Ctrl+L
lock. Mod+Izquierda/Derecha alterna acceso a las islas, Mod+Arriba oculta y
Mod+Abajo fija la barra. No promete previews de Mod+Tab ni shaders del fork.

El wallpaper portable usa fade de awww/swww. No activa el renderer experimental
ni reproduce todos los efectos de transición personales. Añade imágenes a
`~/Pictures/Wallpapers` y usa el carrusel; el repositorio no incluye wallpapers.
Se crean adaptadores awww→swww y magick→convert si hacen falta y están presentes.

## Primera sesión y seguridad

El servicio se habilita solo con `--enable`, **sin** `--now`: no se arranca otra
shell en el escritorio actual. Inicia Niri desde tu display manager, o mediante
`niri-session`/`niri --session` según el paquete. Asegura que `~/.local/bin` esté
en tu PATH de sesión. El servicio de la shell tiene su PATH explícito.

PipeWire/WirePlumber, NetworkManager y Bluetooth deben estar configurados por
tu distribución. El instalador no reemplaza PulseAudio, no apaga otros servicios
ni configura interfaces de red. No actives dos servidores de notificaciones
simultáneos: Haku usa org.freedesktop.Notifications.

**Bloqueo:** antes de usar Mod+Ctrl+L, instala/configura un servicio PAM válido
`/etc/pam.d/hyprlock` siguiendo tu distribución (por ejemplo, el proporcionado
por su paquete hyprlock). El cliente rechaza bloquear si falta ese archivo.
No se genera una política PAM universal, no se cambian contraseñas, y nunca
se prueba el bloqueo real automáticamente. Prueba primero `haku-lock --preview`.
El módulo NixOS declara ese servicio mediante la infraestructura PAM de NixOS.

El gestor integrado de paquetes y sus comprobaciones son de Arch y necesitan
`yay` (no se instala automáticamente desde AUR). En Arch sin yay y en otras
distros se deshabilitan para no ejecutar comandos inexistentes. Usa apt o la configuración
NixOS fuera de la shell. No se promete un gestor gráfico multiplataforma.

## Restaurar configuraciones

```sh
./install.sh --restore ~/.local/state/haku-installer/backups/FECHA
./install.sh --restore ~/.local/state/haku-installer/backups/FECHA --apply
systemctl --user daemon-reload
```

La primera orden muestra el plan. La restauración rechaza sobrescribir archivos
editados después de instalar. Revisa esos conflictos manualmente. No desinstala
paquetes ni quita el alias del checkout, carpetas vacías o habilitación del
servicio. Para deshabilitar el servicio en una sesión posterior:
`systemctl --user disable haku-quickshell.service`.

## NixOS y Home Manager

No uses `./install.sh --apply` en NixOS. Ejemplo con un checkout disponible
junto a tu configuración (ajusta la ruta):

```nix
# configuration.nix
{
  imports = [ ./haku_shell/nix/nixos.nix ];
  services.hakuDesktop.enable = true;
}
```

```nix
# home.nix, para tu usuario de Home Manager
{
  imports = [ ./haku_shell/nix/home.nix ];
  programs.hakuShell = {
    enable = true;
    keyboardLayout = "latam";
    # false si quieres conservar tus KDL propios:
    installNiriConfig = true;
  };
}
```

El módulo de sistema habilita Niri, PipeWire/Pulse/WirePlumber, RTKit,
NetworkManager, Bluetooth, UPower y el servicio PAM de bloqueo. Revisa posibles
conflictos con PulseAudio/red antes de `nixos-rebuild`. No elige display manager,
NVIDIA, discos, energía ni shell de login. El módulo de usuario construye los
helpers Rust con sus Cargo.lock, instala runtime/scripts y el servicio.
No instala las configuraciones personales del fork ni tematiza todos los apps.

Home Manager administra `~/haku_shell` como enlace al store; clona la fuente
en otro lugar (por ejemplo `~/src/haku_shell`) si usas este módulo. Los archivos
conflictivos no se sobrescriben silenciosamente: revisa/respáldalos antes de
activar. Las actualizaciones pasan por rebuild; no edites el enlace al store.

La flake exporta `nixosModules.default`, `homeManagerModules.default` y los
helpers como `packages.<system>.default` (x86_64-linux/aarch64-linux).
Genera y conserva un `flake.lock` en tu configuración para fijar nixpkgs.
No hay lock generado aquí porque Nix no está disponible para validarlo.

Validación pendiente en un equipo Nix:

```sh
nix flake check path:.
nix build path:.#default
```

Estos módulos son una implementación inicial, no un build NixOS ya verificado.

## Pruebas locales

```sh
python3 -m unittest discover -s tests -p test_installer.py -v
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/quickshell
./install.sh --dry-run --distro arch --dependencies
./install.sh --dry-run --distro debian --dependencies
./install.sh --dry-run --distro ubuntu --dependencies
./install.sh --dry-run --distro nixos
```
