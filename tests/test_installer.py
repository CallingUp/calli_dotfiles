import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('haku_installer', ROOT / 'installer/install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='haku-install-test-')
        self.home = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def test_distros(self):
        for content, expected in [('ID=debian\n', 'debian'), ('ID=ubuntu\nID_LIKE=debian\n', 'ubuntu'),
                                  ('ID=cachyos\nID_LIKE=arch\n', 'arch'), ('ID=nixos\n', 'nixos')]:
            path = self.home / 'os-release'; path.write_text(content)
            self.assertEqual(installer.distro(path), expected)

    def test_unknown_distro(self):
        path = self.home / 'os-release'; path.write_text('ID=unknown\n')
        with self.assertRaises(RuntimeError): installer.distro(path)

    def test_dry_run_no_writes(self):
        for family in ('arch', 'ubuntu', 'debian', 'nixos'):
            with patch.object(installer.Path, 'home', return_value=self.home), contextlib.redirect_stdout(io.StringIO()):
                installer.main(['--distro', family, '--dry-run'])
            self.assertEqual(list(self.home.iterdir()), [])

    def test_guided_cancel_no_changes(self):
        with patch.object(installer, 'distro', return_value='arch'), \
             patch.object(installer.Path, 'home', return_value=self.home), \
             patch.object(installer.os, 'geteuid', return_value=1000), \
             patch.object(installer.sys.stdin, 'isatty', return_value=True), \
             patch('builtins.input', side_effect=['latam', '1', '']), \
             patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.main([])
        run.assert_not_called()
        self.assertEqual(list(self.home.iterdir()), [])

    def test_guided_confirm_installs_default_bundle(self):
        with patch.object(installer, 'distro', return_value='arch'), \
             patch.object(installer.Path, 'home', return_value=self.home), \
             patch.object(installer.os, 'geteuid', return_value=1000), \
             patch.object(installer.sys.stdin, 'isatty', return_value=True), \
             patch('builtins.input', side_effect=['latam', '1', 's']), \
             patch.object(installer, 'install_dependencies') as dependencies, \
             patch.object(installer, 'check_qt'), \
             patch.object(installer.shutil, 'which', side_effect=lambda cmd, **kw: '/usr/bin/' + cmd), \
             patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.main([])
        dependencies.assert_any_call('arch', True, False)
        dependencies.assert_any_call('arch', True, True)
        self.assertTrue((self.home / '.config/kitty/kitty.conf').is_file())
        config = (self.home / '.config/niri/config.kdl').read_text()
        self.assertIn('layout "latam"', config)
        calls = [list(map(str, call.args[0])) for call in run.call_args_list]
        self.assertEqual(sum(cmd[:2] == ['cargo', 'build'] for cmd in calls), 5)
        self.assertIn(['systemctl', '--user', 'enable', 'haku-quickshell.service'], calls)

    def test_guided_requires_terminal(self):
        with patch.object(installer.os, 'geteuid', return_value=1000), \
             patch.object(installer.sys.stdin, 'isatty', return_value=False):
            with self.assertRaises(RuntimeError): installer.guided_install('arch')

    def test_guided_interrupt_no_changes(self):
        with patch.object(installer.os, 'geteuid', return_value=1000), \
             patch.object(installer.sys.stdin, 'isatty', return_value=True), \
             patch('builtins.input', side_effect=EOFError), \
             patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.guided_install('arch')
        run.assert_not_called()

    def test_guided_root_refused(self):
        with patch.object(installer.os, 'geteuid', return_value=0):
            with self.assertRaises(RuntimeError): installer.guided_install('arch')

    def test_guided_nixos_only_instructions(self):
        with patch.object(installer, 'distro', return_value='nixos'), \
             patch('builtins.input') as prompt, \
             patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.main([])
        prompt.assert_not_called()
        run.assert_not_called()

    def test_guided_shorin_selection(self):
        with patch.object(installer.os, 'geteuid', return_value=1000), \
             patch.object(installer.sys.stdin, 'isatty', return_value=True), \
             patch('builtins.input', side_effect=['latam', '2', 's']), \
             patch.object(installer, 'main') as main, contextlib.redirect_stdout(io.StringIO()):
            installer.guided_install('arch')
        self.assertEqual(main.call_count, 2)
        self.assertIn('--shorin', main.call_args_list[0].args[0])
        self.assertIn('--dry-run', main.call_args_list[0].args[0])
        self.assertIn('--apply', main.call_args_list[1].args[0])

    def test_shorin_plan_does_not_execute(self):
        with patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.install_shorin('arch', False)
        run.assert_not_called()

    def test_shorin_other_distros_refused(self):
        for family in ('debian', 'ubuntu', 'nixos'):
            with patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(RuntimeError):
                    installer.main(['--distro', family, '--shorin', '--apply'])
            run.assert_not_called()

    def test_shorin_dependencies_do_not_install_upstream_niri(self):
        with patch.object(installer, 'available', return_value=True), \
             patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.install_dependencies('arch', True, True, shorin=True)
        packages = run.call_args.args[0]
        self.assertNotIn('niri', packages)
        self.assertIn('base-devel', packages)

    def test_shorin_build_uses_package_manager_and_limited_jobs(self):
        with patch.object(installer.Path, 'home', return_value=self.home), \
             patch.object(installer.os, 'geteuid', return_value=1000), \
             patch.object(installer.shutil, 'which', return_value='/usr/bin/makepkg'), \
             patch.dict(installer.os.environ, {'CARGO_BUILD_JOBS': '2'}), \
             patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.install_shorin('arch', True)
        self.assertEqual(run.call_args.args[0], ['makepkg', '--syncdeps', '--install', '--needed'])
        self.assertEqual(run.call_args.kwargs['env']['CARGO_BUILD_JOBS'], '2')
        self.assertTrue(str(run.call_args.kwargs['cwd']).startswith(str(self.home / '.cache/haku-installer')))

    def test_plan_dependency_does_not_execute(self):
        with patch.object(installer, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            installer.install_dependencies('ubuntu', True, False)
            run.assert_not_called()

    def test_missing_package_does_not_install(self):
        with patch.object(installer, 'available', return_value=False), patch.object(installer, 'run') as run:
            with self.assertRaises(RuntimeError): installer.install_dependencies('debian', False, True)
            run.assert_not_called()

    def test_backup_and_restore(self):
        target = self.home / '.config/haku/palette.conf'
        target.parent.mkdir(parents=True); target.write_text('original'); target.chmod(0o640)
        backup = installer.deploy({target: (b'new', 0o644)}, self.home)
        self.assertEqual((backup / '.config/haku/palette.conf').read_text(), 'original')
        with contextlib.redirect_stdout(io.StringIO()): installer.restore(backup, self.home, True)
        self.assertEqual(target.read_text(), 'original')
        self.assertEqual(target.stat().st_mode & 0o777, 0o640)

    def test_new_file_restore(self):
        target = self.home / '.local/bin/test'
        backup = installer.deploy({target: (b'new', 0o755)}, self.home)
        with contextlib.redirect_stdout(io.StringIO()): installer.restore(backup, self.home, True)
        self.assertFalse(target.exists())

    def test_full_install_in_temporary_home(self):
        output = io.StringIO()
        with patch.object(installer.Path, 'home', return_value=self.home), \
             patch.object(installer.os, 'geteuid', return_value=1000), \
             patch.object(installer, 'check_qt'), \
             patch.object(installer.shutil, 'which', side_effect=lambda cmd, **kw: '/usr/bin/' + cmd), \
             patch.object(installer, 'run') as run, contextlib.redirect_stdout(output):
            installer.main(['--distro', 'arch', '--apply', '--apps', '--enable'])
        self.assertTrue((self.home / 'haku_shell').is_symlink())
        self.assertTrue((self.home / '.local/bin/wallpaper-transition').is_file())
        self.assertTrue((self.home / '.local/bin/wallpaper-theme-sync').is_file())
        self.assertTrue((self.home / '.local/bin/awww-daemon').is_file())
        self.assertTrue((self.home / '.local/state/haku_theme/colors.css').is_file())
        self.assertTrue((self.home / '.config/gtk-3.0/gtk.css').is_file())
        calls = [list(map(str, call.args[0])) for call in run.call_args_list]
        self.assertIn(['systemctl', '--user', 'enable', 'haku-quickshell.service'], calls)
        self.assertFalse(any('--now' in cmd or 'restart' in cmd for cmd in calls))
        self.assertEqual(len(list((self.home / '.local/state/haku-installer/backups').glob('*/manifest.json'))), 1)

    def test_wallpaper_contract_in_plan(self):
        files = installer.files(self.home, 'portable', False, 'us')
        names = {path.name for path in files}
        self.assertTrue({'wallpaper-transition', 'wallpaper-theme-sync', 'set-wallpaper', 'colors.css'} <= names)

    def test_restore_refuses_later_edit(self):
        target = self.home / '.config/test'
        backup = installer.deploy({target: (b'installed', 0o644)}, self.home)
        target.write_text('user edit')
        with self.assertRaises(RuntimeError): installer.restore(backup, self.home, True)
        self.assertEqual(target.read_text(), 'user edit')

    def test_idempotent(self):
        target = self.home / '.config/test'
        installer.deploy({target: (b'new', 0o644)}, self.home)
        before = target.stat().st_mtime_ns
        backup = installer.deploy({target: (b'new', 0o644)}, self.home)
        self.assertEqual(target.stat().st_mtime_ns, before)
        self.assertEqual(json.loads((backup / 'manifest.json').read_text()), [])

    def test_file_symlink_refused(self):
        target = self.home / 'link'; target.symlink_to('/etc/passwd')
        with self.assertRaises(RuntimeError): installer.deploy({target: (b'bad', 0o644)}, self.home)

    def test_parent_symlink_escape_refused(self):
        target = self.home / 'outside'; target.symlink_to('/tmp', target_is_directory=True)
        with self.assertRaises(RuntimeError): installer.ensure_safe(target / 'bad', self.home)

    def test_restore_escape_refused(self):
        with self.assertRaises(RuntimeError): installer.restore(Path('/tmp'), self.home, False)

    def test_foreign_home_rewritten(self):
        files = installer.files(self.home, 'personal', True, 'latam')
        for target, (data, _) in files.items():
            self.assertNotIn(b'/home/calli', data, str(target))
        self.assertNotIn(b'haku-ssh-unlock', files[self.home / '.config/niri/autostart.kdl'][0])

    def test_portable_no_hardware_or_fork(self):
        config = installer.files(self.home, 'portable', False, 'latam')[self.home / '.config/niri/config.kdl'][0]
        for token in [b'eDP-1', b'1920x1080@144', b'toggle-grid-overview', b'toggle-magnifier', b'latam-not-real']:
            self.assertNotIn(token, config)
        self.assertIn(b'layout "latam"', config)

    def test_non_arch_packages_disabled(self):
        service = self.home / '.config/systemd/user/haku-quickshell.service'
        data = installer.files(self.home, 'portable', False, 'us', 'ubuntu')[service][0]
        self.assertIn(b'HAKU_PACKAGE_BACKEND=disabled', data)

    def test_old_qt_refused(self):
        result = subprocess.CompletedProcess([], 0, stdout='6.8.2+dfsg-7', stderr='')
        with patch.object(installer.subprocess, 'run', return_value=result):
            with self.assertRaises(RuntimeError): installer.check_qt('debian')

    def test_modern_qt_accepted(self):
        result = subprocess.CompletedProcess([], 0, stdout='6.10.2+dfsg-3', stderr='')
        with patch.object(installer.subprocess, 'run', return_value=result): installer.check_qt('ubuntu')

    def test_no_personal_scripts(self):
        files = installer.files(self.home, 'portable', False, 'us')
        names = {p.name for p in files}
        self.assertFalse(names & {'codex', 'clean.sh', 'repartition-pop-disk', 'haku-ssh-unlock', 'haku-shell-profile'})

    def test_bad_keyboard_refused(self):
        with patch.object(installer.Path, 'home', return_value=self.home):
            with self.assertRaises(RuntimeError): installer.main(['--distro', 'arch', '--keyboard', 'us"; quit'])

    def test_nixos_imperative_refused(self):
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError): installer.main(['--distro', 'nixos', '--apply'])

    @unittest.skipUnless(__import__('shutil').which('niri'), 'niri not installed')
    def test_portable_niri_validation(self):
        content = installer.files(self.home, 'portable', False, 'us')[self.home / '.config/niri/config.kdl'][0]
        config = self.home / 'test.kdl'; config.write_bytes(content)
        result = subprocess.run(['niri', 'validate', '-c', str(config)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__': unittest.main()
