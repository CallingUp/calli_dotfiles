#!/usr/bin/env python3
"""File-scoped installer: dry run by default, explicit package/build actions."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
TOOLS = ('haku-info', 'haku-metrics', 'haku-clipboard', 'haku-connectivity', 'haku-wallpaper')
SCRIPTS = ('haku-lock', 'haku-waybar-visibility', 'haku-clipboard', 'haku-clipboard-worker',
           'haku-connectivity-worker', 'haku-info-worker', 'haku-theme-worker',
           'haku-wallpaper-worker', 'haku-wallpaper-selector', 'wallpaper-carousel',
           'haku-shortcuts', 'haku-qml-menu', 'haku-osd-control', 'get_accent_color.py')
APP_CONFIGS = ('kitty', 'alacritty', 'gtk-3.0', 'gtk-4.0', 'qt5ct', 'qt6ct')


def distro(path=Path('/etc/os-release')):
    data = {}
    for line in path.read_text().splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            data[k] = v.strip('"\'')
    ids = [data.get('ID', '')] + data.get('ID_LIKE', '').split()
    for name in ('nixos', 'arch', 'ubuntu', 'debian'):
        if name in ids:
            return name
    raise RuntimeError('Distribución no soportada: ' + data.get('ID', 'unknown'))


def run(args):
    print('+', shlex.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), check=True)


def available(package, family):
    cmd = ['pacman', '-Si', package] if family == 'arch' else ['apt-cache', 'policy', package]
    result = subprocess.run(cmd, text=True, capture_output=True, env={**os.environ, 'LC_ALL': 'C'})
    if family == 'arch':
        return result.returncode == 0
    return bool(re.search(r'Candidate:\s+(?!\(none\))\S+', result.stdout))


def install_dependencies(family, build, apply):
    family = 'debian' if family == 'ubuntu' else family
    specs = json.loads((REPO / 'installer/packages.json').read_text())[family]
    packages = specs['base'] + (specs['build'] if build else [])
    if not apply:
        print('Paquetes:', ' '.join(packages), '+ awww o swww')
        print('Sin añadir PPA, backports ni AUR automáticamente.')
        return
    missing = [p for p in packages if not available(p, family)]
    wallpaper = next((p for p in specs['wallpaper'] if available(p, family)), None)
    if not wallpaper:
        missing.append('awww o swww')
    if missing:
        raise RuntimeError('Sin candidato en tus repositorios: ' + ', '.join(missing)
                           + '. Revisa docs/INSTALL.md; no se copiaron configuraciones.')
    prefix = ['sudo', 'pacman', '-S', '--needed'] if family == 'arch' else ['sudo', 'apt-get', 'install']
    run(prefix + packages + [wallpaper])


def render(text, home):
    return text.replace('/home/calli/haku_shell', str(home / 'haku_shell')).replace('/home/calli', str(home))


def check_qt(family):
    if family == 'arch':
        result = subprocess.run(['pacman', '-Q', 'qt6-base'], text=True, capture_output=True)
        version = result.stdout
    else:
        version = ''
        for package in ('libqt6core6t64', 'libqt6core6'):
            result = subprocess.run(['dpkg-query', '-W', '-f=${Version}', package], text=True, capture_output=True)
            if result.returncode == 0:
                version = result.stdout
                break
    match = re.search(r'(\d+)\.(\d+)', version)
    if not match or tuple(map(int, match.groups())) < (6, 9):
        raise RuntimeError('Esta shell necesita Qt >= 6.9 (RectangularShadow). No se mezclarán repositorios Qt automáticamente.')


def files(home, profile, apps, keyboard, family='arch'):
    result = {}
    for src in sorted((REPO / 'config/haku').glob('*')):
        result[home / '.config/haku' / src.name] = (src.read_bytes(), 0o644)
    for name in SCRIPTS:
        src = REPO / 'scripts/bin' / name
        result[home / '.local/bin' / name] = (render(src.read_text(), home).encode(), 0o755)
    for name, src in [('set-wallpaper', 'set-wallpaper'), ('haku-wallpaper-restore', 'wallpaper-restore'),
                      ('wallpaper-transition', 'wallpaper-transition'), ('wallpaper-theme-sync', 'wallpaper-theme-sync')]:
        result[home / '.local/bin' / name] = ((REPO / 'installer' / src).read_bytes(), 0o755)
    for name, fallback in [('awww', 'swww'), ('awww-daemon', 'swww-daemon')]:
        executable = shutil.which(name, path='/usr/local/bin:/usr/bin:/bin') or shutil.which(fallback) or fallback
        result[home / '.local/bin' / name] = (f'#!/bin/sh\nexec {shlex.quote(executable)} "$@"\n'.encode(), 0o755)
    if not shutil.which('magick') and shutil.which('convert'):
        result[home / '.local/bin/magick'] = (f'#!/bin/sh\nexec {shlex.quote(shutil.which("convert"))} "$@"\n'.encode(), 0o755)
    # Fresh clones need the compatibility color state used by carousel/clipboard.
    palette = (REPO / 'config/haku/palette.conf').read_text()
    values = dict(re.findall(r'^([A-Z_]+)="(#[0-9A-Fa-f]{6})"$', palette, re.M))
    css = ''.join(f'@define-color {name} {values[key]};\n' for name, key in
                  [('accent_color', 'ACCENT'), ('accent_active', 'ACTIVE'), ('accent_inactive', 'INACTIVE')])
    result[home / '.local/state/haku_theme/colors.css'] = (css.encode(), 0o644)
    if apps:
        for item in APP_CONFIGS:
            for src in sorted((REPO / 'config' / item).rglob('*')):
                if src.is_file():
                    target = home / '.config' / item / src.relative_to(REPO / 'config' / item)
                    result[target] = (render(src.read_text(), home).encode(), 0o644)
    if profile == 'personal':
        for src in sorted((REPO / 'config/niri').glob('*.kdl')):
            result[home / '.config/niri' / src.name] = (render(src.read_text(), home).encode(), 0o644)
        target = home / '.config/niri/autostart.kdl'
        startup = result[target][0].decode()
        startup = '\n'.join(l for l in startup.splitlines() if 'haku-keyring-unlock' not in l and 'haku-ssh-unlock' not in l) + '\n'
        result[target] = (startup.encode(), 0o644)
    else:
        text = (REPO / 'installer/niri-portable.kdl').read_text()
        text = text.replace('@HOME@', str(home)).replace('@KEYBOARD@', keyboard)
        result[home / '.config/niri/config.kdl'] = (text.encode(), 0o644)
    quickshell = shutil.which('quickshell') or '/usr/bin/quickshell'
    # Do not persist the invoking terminal's temporary/Codex/private PATH entries.
    path = ':'.join([str(home / '.local/bin'), str(home / '.nix-profile/bin'),
                     '/usr/local/bin', '/usr/bin', '/bin', '/usr/local/sbin', '/usr/sbin'])
    def quote(value):
        return '"' + value.replace('%', '%%').replace('\\', '\\\\').replace('"', '\\"') + '"'
    unit = ('[Unit]\nDescription=Haku QuickShell\nPartOf=graphical-session.target\nAfter=graphical-session.target\n'
            '[Service]\nType=simple\nEnvironment=' + quote('PATH=' + path) + '\n'
            'ExecStart=' + quote(quickshell) + ' -p ' + quote(str(home / 'haku_shell/config/quickshell/minflair-niri/niri-preview.qml'))
            + '\nRestart=on-failure\nRestartSec=2\n[Install]\nWantedBy=graphical-session.target\n')
    if family != 'arch' or not shutil.which('yay'):
        unit = unit.replace('[Service]\n', '[Service]\nEnvironment=HAKU_PACKAGE_BACKEND=disabled\n')
    result[home / '.config/systemd/user/haku-quickshell.service'] = (unit.encode(), 0o644)
    return result


def ensure_safe(target, home):
    if not target.is_relative_to(home) or target == home:
        raise RuntimeError('Destino fuera del HOME: ' + str(target))
    if not target.parent.resolve().is_relative_to(home.resolve()):
        raise RuntimeError('Directorio enlazado fuera del HOME: ' + str(target))
    if target.is_symlink() or target.is_dir():
        raise RuntimeError('Destino enlazado/directorio: revísalo manualmente: ' + str(target))


def deploy(planned, home):
    for target in planned:
        ensure_safe(target, home)
    backup = home / '.local/state/haku-installer/backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    ensure_safe(backup / 'manifest.json', home)
    backup.mkdir(parents=True, mode=0o700)
    entries = []
    for target, (content, mode) in planned.items():
        if target.exists() and target.read_bytes() == content and target.stat().st_mode & 0o777 == mode:
            continue
        relative = target.relative_to(home)
        if target.exists():
            old = backup / relative
            old.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, old)
        entries.append({'path': str(relative), 'existed': target.exists(), 'sha256': hashlib.sha256(content).hexdigest()})
        # Journal before replacing: useful even if a later write fails.
        (backup / 'manifest.json').write_text(json.dumps(entries, indent=2))
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.haku-', delete=False) as stream:
            stream.write(content)
            temporary = Path(stream.name)
        temporary.chmod(mode)
        temporary.replace(target)
    (backup / 'manifest.json').write_text(json.dumps(entries, indent=2))
    return backup


def restore(backup, home, apply):
    backup = backup.resolve()
    base = (home / '.local/state/haku-installer/backups').resolve()
    if not backup.is_relative_to(base) or backup == base:
        raise RuntimeError('El respaldo debe estar en ~/.local/state/haku-installer/backups/')
    entries = json.loads((backup / 'manifest.json').read_text())
    for entry in entries:
        if Path(entry['path']).is_absolute():
            raise RuntimeError('Ruta absoluta en el manifiesto')
        target = home / entry['path']
        ensure_safe(target, home)
        if '..' in Path(entry['path']).parts:
            raise RuntimeError('Ruta inválida en el manifiesto')
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != entry['sha256']:
            raise RuntimeError('Archivo editado después de instalar; no se sobrescribe: ' + str(target))
        saved = backup / entry['path']
        if entry['existed'] and (not saved.is_file() or saved.is_symlink()):
            raise RuntimeError('Respaldo incompleto: ' + str(saved))
        print('Restaurar:', target)
    if apply:
        for entry in entries:
            target = home / entry['path']
            if entry['existed']:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(backup / entry['path'], target)
            elif target.exists():
                target.unlink()
        print('Restaurados los archivos; paquetes, alias del checkout y habilitación del servicio no se revierten.')


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--apply', action='store_true')
    p.add_argument('--dry-run', action='store_true', help='Vista previa explícita (también es el valor por defecto)')
    p.add_argument('--distro', choices=('auto', 'arch', 'debian', 'ubuntu', 'nixos'), default='auto')
    p.add_argument('--dependencies', action='store_true')
    p.add_argument('--build', action='store_true', help='Compilar cinco helpers Rust con --locked')
    p.add_argument('--enable', action='store_true', help='Habilitar servicio para la próxima sesión, sin arrancarlo')
    p.add_argument('--apps', action='store_true', help='Copiar paletas Kitty/Alacritty/GTK/Qt')
    p.add_argument('--profile', choices=('portable', 'personal'), default='portable')
    p.add_argument('--keyboard', default='us')
    p.add_argument('--restore', type=Path, help='Restaurar un respaldo; requiere --apply para escribir')
    args = p.parse_args(argv)
    if args.apply and args.dry_run:
        raise RuntimeError('--apply y --dry-run son incompatibles')
    home = Path.home()
    if args.restore:
        if args.apply and os.geteuid() == 0:
            raise RuntimeError('No ejecutes la restauración con sudo')
        restore(args.restore, home, args.apply)
        return
    family = distro() if args.distro == 'auto' else args.distro
    if family == 'nixos':
        print('NixOS: usa nix/nixos.nix y nix/home.nix; instrucciones en docs/INSTALL.md.')
        if args.apply or args.dependencies or args.build:
            raise RuntimeError('NixOS requiere los módulos declarativos, no instalación imperativa.')
        return
    if not re.fullmatch(r'[a-zA-Z0-9_,()-]+', args.keyboard):
        raise RuntimeError('Distribución de teclado inválida')
    if any(c in str(home) for c in ('"', "'", '\\', '\n', '\r')):
        raise RuntimeError('HOME contiene caracteres no soportados por las rutas KDL')
    if args.apply and os.geteuid() == 0:
        raise RuntimeError('Ejecuta como usuario, no con sudo; solo el gestor de paquetes usa sudo.')
    canonical = home / 'haku_shell'
    if (canonical.exists() or canonical.is_symlink()) and canonical.resolve() != REPO:
        raise RuntimeError('~/haku_shell ya apunta a otro checkout; no se sobrescribe')
    print(f'Distribución: {family}; perfil: {args.profile}; aplicar: {args.apply}')
    if args.profile == 'personal':
        print('Requiere fork SHORiN (grid overview, lupa, opacity toggle); no se instala automáticamente.')
    if args.dependencies:
        install_dependencies(family, args.build, args.apply)
    planned = files(home, args.profile, args.apps, args.keyboard, family)
    for target in planned:
        if args.apply:
            ensure_safe(target, home)
        print('Archivo:', target)
    print('Alias del checkout:', canonical, '->', REPO)
    print('No modifica SDDM, PAM, drivers, discos, SSH, shell de login ni servicios del sistema.')
    if not args.apply:
        print('Vista previa. Añade --apply para instalar.')
        return
    required = ['niri', 'quickshell', 'kitty', 'wl-paste', 'cliphist', 'python3']
    missing = [cmd for cmd in required if not shutil.which(cmd)]
    if missing:
        raise RuntimeError('Faltan comandos: ' + ', '.join(missing) + '; usa --dependencies')
    check_qt(family)
    if not shutil.which('awww') and not shutil.which('swww'):
        raise RuntimeError('Falta awww o swww para el wallpaper')
    if not shutil.which('magick') and not shutil.which('convert'):
        raise RuntimeError('Falta ImageMagick (magick o convert) para las miniaturas')
    if args.build:
        for tool in TOOLS:
            run(['cargo', 'build', '--release', '--locked', '--manifest-path', REPO / 'tools' / tool / 'Cargo.toml'])
    with tempfile.TemporaryDirectory(prefix='haku-validate-') as tmp:
        staging = Path(tmp)
        for target, (content, _) in planned.items():
            if target.parent == home / '.config/niri':
                (staging / target.name).write_bytes(content)
        run(['niri', 'validate', '-c', staging / 'config.kdl'])
    backup = deploy(planned, home)
    if not canonical.exists():
        canonical.symlink_to(REPO, target_is_directory=True)
    (home / 'Pictures/Wallpapers').mkdir(parents=True, exist_ok=True)
    run(['systemctl', '--user', 'daemon-reload'])
    if args.enable:
        run(['systemctl', '--user', 'enable', 'haku-quickshell.service'])
    print('Instalado. Respaldo:', backup)
    print('Inicia una sesión Niri; no se reinició el escritorio actual.')
    print('Lock: requiere servicio PAM hyprlock válido; revisa docs/INSTALL.md antes de usarlo.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print('ERROR:', error, file=sys.stderr)
        raise SystemExit(1)
