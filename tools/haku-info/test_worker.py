"""Read-only migration checks; parser fixtures never execute their bindings."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).parent
BASE=ROOT.parents[1]
BINARY=ROOT/'target/release/haku-info'
OLD=runpy.run_path(str(BASE/'config/quickshell/haku-shortcuts/shortcuts.py'))

class Tests(unittest.TestCase):
    def native(self,*args,env=None):
        return json.loads(subprocess.check_output([str(BINARY),*map(str,args)],text=True,env=env,timeout=30))

    def test_actual_bindings_match(self):
        path=Path.home()/'.config/niri/config.kdl'
        result=self.native('shortcuts',path)
        self.assertEqual(result['error'],'')
        self.assertEqual(result['rows'],OLD['collect'](path))

    def test_parser_includes_cycle_comments_and_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);main=root/'config.kdl';child=root/'recent-windows.kdl'
            main.write_text('''/* Mod+Bad { spawn "never"; } */
// Applications
include "recent-windows.kdl"
include "recent-windows.kdl"
binds {
    Mod+Return hotkey-overlay-title="Terminal" { spawn "kitty"; }
    "Mod+apostrophe" hotkey-overlay-title="Ayuda" {
        // ignored comment
        spawn "bash" "not-executed";
    }
    Mod+H hotkey-overlay-title=null { spawn "hidden"; }
    XF86AudioMute { spawn "mute"; }
}
''')
            child.write_text('include "config.kdl"\nMod+Tab { spawn "switch"; }\n')
            self.assertEqual(self.native('shortcuts',main)['rows'],OLD['collect'](main))

    def test_multiline_escaped_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'keys.kdl'
            path.write_text('Mod+X hotkey-overlay-title="A \\"quote\\"" {\n spawn "test";\n}\n')
            self.assertEqual(self.native('shortcuts',path)['rows'],OLD['collect'](path))

    def test_missing_file(self):
        self.assertEqual(self.native('shortcuts','/nonexistent/haku-info-test'),{'rows':[],'error':''})

    def test_invalid_utf8_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'keys.kdl';path.write_bytes(b'\xff')
            result=self.native('shortcuts',path)
            self.assertTrue(result['error']);self.assertEqual(result['rows'],[])

    def test_system_contract_and_fake_external_tools(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            pacman=root/'pacman'
            pacman.write_text('#!/bin/sh\ncase "$1" in -Qn) printf "one 1\\ntwo 2\\nthree 3\\n";; -Qm) printf "aur 1\\n";; esac\n');pacman.chmod(0o700)
            lspci=root/'lspci'
            lspci.write_text('#!/bin/sh\nprintf "01:00.0 VGA compatible controller: NVIDIA Corporation TU116 [GeForce GTX Test] (rev a1)\\n"\n');lspci.chmod(0o700)
            result=self.native('system',env={**os.environ,'PATH':str(root)+':'+os.environ['PATH']})
            self.assertEqual(result['packages'],'3 (pacman), 1 (aur)')
            self.assertEqual(result['gpus'],'NVIDIA GeForce GTX Test')
            self.assertEqual(result['wm'],'Niri (Wayland)')
            expected={'os','host','kernel','hostname','username','shell','wm','packages','display','cpu_model','cpu_cores','ram_total','disk_total','gpus'}
            self.assertEqual(set(result),expected)
            self.assertTrue(all(isinstance(v,str) for v in result.values()))

    def compare_players(self,env):
        old=BASE/'config/quickshell/minflair-niri/Modules/Music/scripts/get_music_players.py'
        previous=json.loads(subprocess.check_output(['/usr/bin/python3',str(old)],env=env,text=True,timeout=30))
        current=self.native('players',env=env)
        self.assertEqual(current,previous)
        return current

    def test_actual_players_match(self):
        self.compare_players(os.environ.copy())

    def test_player_fixtures_and_no_execution(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);apps=root/'data/applications';apps.mkdir(parents=True)
            bins=root/'bin';bins.mkdir()
            for name in ['fixtureplayer','excludedplayer','hiddenplayer','kew','cmus']:
                executable=bins/name
                executable.write_text('#!/bin/sh\ntouch "'+str(root/'MUST_NOT_EXECUTE')+'"\n')
                executable.chmod(0o700)
            (apps/'fixture.desktop').write_text('[Desktop Entry]\nName=Fixture Music\nExec=fixtureplayer %U\nIcon=music\nCategories=Music;Audio;\n')
            (apps/'duplicate.desktop').write_text('[Desktop Entry]\nName=Duplicate Music\nExec=fixtureplayer %F\nCategories=Music;\n')
            (apps/'hidden.desktop').write_text('[Desktop Entry]\nName=Hidden Music\nExec=hiddenplayer\nNoDisplay=true\nCategories=Music;\n')
            (apps/'excluded.desktop').write_text('[Desktop Entry]\nName=Fixture Recorder\nExec=excludedplayer\nCategories=AudioVideo;Recorder;\n')
            (apps/'defaults.desktop').write_text('[DEFAULT]\nIcon=music\n[Desktop Entry]\nName=Kew\nExec=kew\nTerminal=true\nCategories=Music;\n[Desktop Action Other]\nExec=unused\n')
            env={**os.environ,'HOME':str(root),'PATH':str(bins),'XDG_DATA_DIRS':str(root/'data')}
            rows=self.compare_players(env)
            self.assertEqual(sum(r['id']=='fixtureplayer' for r in rows),1)
            self.assertTrue(next(r for r in rows if r['id']=='cmus')['terminal'])
            self.assertTrue(next(r for r in rows if r['id']=='kew')['terminal'])
            self.assertFalse(any(r['id'] in ['hiddenplayer','excludedplayer'] for r in rows))
            self.assertFalse((root/'MUST_NOT_EXECUTE').exists())

    def test_players_skip_malformed_desktop(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);apps=root/'data/applications';apps.mkdir(parents=True)
            (apps/'broken.desktop').write_text('[Desktop Entry]\nName=A\nName=B\nExec=/does/not/exist\nCategories=Music;\n')
            self.compare_players({**os.environ,'HOME':str(root),'XDG_DATA_DIRS':str(root/'data'),'PATH':str(root/'bin')})

if __name__=='__main__':unittest.main()
