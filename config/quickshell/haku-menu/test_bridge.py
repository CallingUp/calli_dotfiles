import contextlib
import importlib.machinery
import importlib.util
import io
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

bridge_path = Path(__file__).resolve().parents[3] / 'scripts/bin/haku-qml-menu'
loader = importlib.machinery.SourceFileLoader('menu_bridge', str(bridge_path))
spec = importlib.util.spec_from_loader(loader.name, loader)
bridge = importlib.util.module_from_spec(spec)
loader.exec_module(bridge)


class BridgeTests(unittest.TestCase):
    def test_metadata(self):
        rows, headers = bridge.parse_rows('\0prompt\x1fWallpaper\n\0data\x1flocal\nA.png\0icon\x1f/a.png\x1finfo\x1flocal|A.png\n')
        self.assertEqual(headers, {'prompt': 'Wallpaper', 'data': 'local'})
        self.assertEqual(rows[0], {'label': 'A.png', 'icon': '/a.png', 'info': 'local|A.png', 'index': 0})

    def test_options(self):
        opts = bridge.options(['-dmenu', '-i', '-p', 'Clipboard', '-kb-custom-1', 'Alt+Delete'])
        self.assertTrue(opts['-dmenu'])
        self.assertEqual(opts['-kb-custom-1'], 'Alt+Delete')

    def test_return_codes_and_exact_text(self):
        for code in (0, 1, 10):
            output = io.StringIO()
            result = {'code': code, 'index': 0, 'text': "123\tquote ' $HOME `test`"}
            with patch.object(bridge, 'select', return_value=result), patch('sys.stdin', io.StringIO(result['text'])), contextlib.redirect_stdout(output):
                self.assertEqual(bridge.run(['-dmenu']), code)
            self.assertEqual(output.getvalue(), '' if code == 1 else result['text'] + '\n')

    def test_custom_input(self):
        with patch.object(bridge, 'select', return_value={'code': 0, 'index': -1, 'text': '#abcdef'}), patch('sys.stdin', io.StringIO('')), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(bridge.run(['-dmenu']), 0)
        self.assertEqual(output.getvalue(), '#abcdef\n')

    def test_script_protocol(self):
        # No actual scripts, connections or wallpaper actions execute here.
        runs = [SimpleNamespace(stdout='\0data\x1flocal\nA\0info\x1flocal|A\n', returncode=0), SimpleNamespace(stdout='', returncode=0)]
        with patch.object(bridge.subprocess, 'run', side_effect=runs) as runner, patch.object(bridge, 'select', return_value={'code': 0, 'index': 0, 'text': 'A'}):
            self.assertEqual(bridge.run(['-show', 'wallpaper', '-modes', 'wallpaper:/fake/script']), 0)
        self.assertEqual(runner.call_args.kwargs['env']['ROFI_RETV'], '1')
        self.assertEqual(runner.call_args.kwargs['env']['ROFI_INFO'], 'local|A')
        self.assertEqual(runner.call_args.kwargs['env']['ROFI_DATA'], 'local')
        self.assertEqual(runner.call_args.args[0], ['/fake/script', 'A'])


if __name__ == '__main__':
    unittest.main()
