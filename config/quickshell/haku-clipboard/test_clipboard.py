import io
from pathlib import Path
import runpy
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

backend = runpy.run_path(str(Path(__file__).resolve().parents[3] / 'scripts/bin/haku-clipboard'))


class ClipboardTests(unittest.TestCase):
    def test_cleanup_only_private_session_directory(self):
        with tempfile.TemporaryDirectory() as runtime:
            cache = Path(tempfile.mkdtemp(prefix='haku-clipboard-', dir=runtime))
            with patch.dict('os.environ', XDG_RUNTIME_DIR=runtime):
                with self.assertRaises(ValueError): backend['worker'](['cleanup', runtime])
                self.assertTrue(backend['worker'](['cleanup', str(cache)])['ok'])
                self.assertFalse(cache.exists())

    def test_cleanup_refuses_unexpected_files(self):
        with tempfile.TemporaryDirectory() as runtime:
            cache = Path(tempfile.mkdtemp(prefix='haku-clipboard-', dir=runtime))
            (cache / 'keep.txt').touch()
            with patch.dict('os.environ', XDG_RUNTIME_DIR=runtime):
                with self.assertRaises(ValueError): backend['worker'](['cleanup', str(cache)])
            self.assertTrue((cache / 'keep.txt').exists())

    def test_classify(self):
        classify = backend['classify']
        self.assertEqual(classify('https://example.org/'), 'link')
        self.assertEqual(classify('[[ binary data 20 KiB png 640x480 ]]'), 'image')
        self.assertEqual(classify('[[ binary data 20 KiB ]]'), 'binary')
        self.assertEqual(classify('<b>not markup</b>'), 'text')

    def test_image_signature(self):
        self.assertEqual(backend['image_extension'](b'\x89PNG\r\n\x1a\nrest'), 'png')
        self.assertEqual(backend['image_extension'](b'RIFFxxxxWEBPrest'), 'webp')
        self.assertEqual(backend['image_extension'](b'plain text'), '')

    def test_invalid_id_never_executes(self):
        with patch('subprocess.run') as run, patch('subprocess.Popen') as popen:
            with self.assertRaises(ValueError):
                backend['worker'](['delete', '1; touch /tmp/unsafe'])
        run.assert_not_called()
        popen.assert_not_called()

    def test_list_hides_id_and_preserves_text(self):
        result = SimpleNamespace(stdout='42\tquote \' $HOME\n43\thttps://example.org\n', returncode=0)
        with patch('subprocess.run', return_value=result):
            rows = backend['entries']()
        self.assertEqual(rows[0]['label'], "quote ' $HOME")
        self.assertEqual(rows[0]['id'], '42')
        self.assertEqual(rows[1]['kind'], 'link')

    def test_delete_uses_exact_row_stdin(self):
        line = "42\tquote ' $HOME `test`"
        result = SimpleNamespace(stdout=line + '\n', returncode=0)
        with patch('subprocess.run', return_value=result) as run:
            backend['worker'](['delete', '42'])
        deletion = run.call_args_list[1]
        self.assertEqual(deletion.args[0], ['cliphist', 'delete'])
        self.assertEqual(deletion.kwargs['input'], line + '\n')

    def test_copy_streams_original_without_preview_limit(self):
        with patch('subprocess.run') as run:
            self.assertTrue(backend['worker'](['copy', '42'])['ok'])
        self.assertEqual(run.call_args_list[0].args[0], ['cliphist', 'decode', '42'])
        self.assertEqual(run.call_args_list[1].args[0], ['wl-copy'])
        self.assertNotIn('input', run.call_args_list[1].kwargs)

    def test_text_preview_preserves_multiline_plain_text(self):
        with patch.dict(backend['worker'].__globals__, decode=lambda _: b'<b>plain</b>\nsecond line'):
            result = backend['worker'](['preview', '42', '/unused'])
        self.assertEqual(result['text'], '<b>plain</b>\nsecond line')
        self.assertEqual(result['image'], '')

    def test_image_preview_private_cache(self):
        with tempfile.TemporaryDirectory() as cache, patch.dict(backend['worker'].__globals__, decode=lambda _: b'\x89PNG\r\n\x1a\nfixture'):
            result = backend['worker'](['preview', '42', cache])
            preview = Path(result['image'])
            self.assertEqual(preview.parent, Path(cache))
            self.assertEqual(preview.stat().st_mode & 0o777, 0o600)


if __name__ == '__main__':
    unittest.main()
