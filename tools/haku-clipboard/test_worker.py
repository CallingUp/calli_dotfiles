"""Exercise the compiled worker against fake tools, never the real clipboard."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BINARY = Path(__file__).parent / 'target/release/haku-clipboard'


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = {**os.environ, 'PATH': str(self.root) + ':' + os.environ['PATH'],
                    'XDG_RUNTIME_DIR': str(self.root), 'FAKE_ROOT': str(self.root)}
        # Scripts are test fixtures, not wrappers around the user's tools.
        cliphist = self.root / 'cliphist'
        cliphist.write_text('''#!/bin/sh
case "$1" in
list) printf '42\t$HOME `literal`\n43\thttps://example.org\n';;
decode) cat "$FAKE_ROOT/data";;
delete) cat > "$FAKE_ROOT/deleted";;
wipe) touch "$FAKE_ROOT/wiped";;
*) exit 2;;
esac
''')
        cliphist.chmod(0o700)
        copy = self.root / 'wl-copy'
        copy.write_text('#!/bin/sh\ncat > "$FAKE_ROOT/copied"\n')
        copy.chmod(0o700)
        (self.root / 'data').write_bytes(b'hello')

    def run_worker(self, *args, success=True):
        result = subprocess.run([str(BINARY), *args], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return json.loads(result.stdout)

    def test_session_private_and_cleanup(self):
        state = self.root / '.local/state/haku_theme'
        state.mkdir(parents=True)
        (state / 'colors.css').write_text('@define-color accent_color #B99573;\n')
        (state / 'fonts.css').write_text('font-family: "Maple Mono NF";\n')
        self.env['HOME'] = str(self.root)
        data = self.run_worker('session')
        self.assertEqual(data['accent'], '#B99573')
        self.assertEqual(data['font'], 'Maple Mono NF')
        cache = Path(data['cacheDir'])
        self.assertEqual(cache.stat().st_mode & 0o777, 0o700)
        self.assertEqual(data['rows'][0]['label'], '$HOME `literal`')
        self.run_worker('cleanup', str(cache))
        self.assertFalse(cache.exists())

    def test_copy_exact_original_larger_than_preview_limit(self):
        original = b'x' * (16 * 1024 * 1024 + 1)
        (self.root / 'data').write_bytes(original)
        self.run_worker('copy', '42')
        self.assertEqual((self.root / 'copied').read_bytes(), original)
        self.run_worker('preview', '42', str(self.root), success=False)

    def test_delete_literal_stdin_and_invalid_id(self):
        self.run_worker('delete', '42')
        self.assertEqual((self.root / 'deleted').read_bytes(), b'42\t$HOME `literal`\n')
        self.run_worker('delete', '42;echo', success=False)

    def test_image_preview_and_symlink_target(self):
        data = b'\x89PNG\r\n\x1a\nimage'
        (self.root / 'data').write_bytes(data)
        cache = Path(self.run_worker('session')['cacheDir'])
        outside = self.root / 'untouched'
        outside.write_bytes(b'keep')
        (cache / 'preview-42.png').symlink_to(outside)
        result = self.run_worker('preview', '42', str(cache))
        self.assertEqual(Path(result['image']).read_bytes(), data)
        self.assertEqual(Path(result['image']).stat().st_mode & 0o777, 0o600)
        self.assertEqual(outside.read_bytes(), b'keep')
        self.run_worker('cleanup', str(cache))

    def test_text_unicode_truncation(self):
        (self.root / 'data').write_bytes(('á' * 65537).encode())
        result = self.run_worker('preview', '42', str(self.root))
        self.assertEqual(len(result['text']), 65536)
        self.assertTrue(result['truncated'])

    def test_cleanup_rejects_broad_target_and_unexpected_files(self):
        self.run_worker('cleanup', str(self.root), success=False)
        cache = Path(self.run_worker('session')['cacheDir'])
        keep = cache / 'keep.txt'
        keep.touch()
        self.run_worker('cleanup', str(cache), success=False)
        self.assertTrue(keep.exists())

    def test_wipe_fake_only(self):
        self.assertTrue(self.run_worker('wipe')['ok'])
        self.assertTrue((self.root / 'wiped').exists())


if __name__ == '__main__':
    unittest.main()
