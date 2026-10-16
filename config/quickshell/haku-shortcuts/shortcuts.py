"""Read live Niri binds without executing any of their actions."""
import json
import re
from pathlib import Path


def collect(path, seen=None):
    seen = set() if seen is None else seen
    path = path.resolve()
    if path in seen or not path.is_file():
        return []
    seen.add(path)
    text = path.read_text()
    # Remove block comments while preserving line positions.
    text = re.sub(r'/\*.*?\*/', lambda m: '\n' * m[0].count('\n'), text, flags=re.S)
    rows = []
    section = 'General'
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        comment = re.match(r'^\s*//\s*([\wÁÉÍÓÚáéíóú].*)$', line)
        if comment:
            section = comment[1].strip()
            section = {'Help': 'Ayuda', 'Applications': 'Aplicaciones',
                       'Noctalia': 'Shell', 'Session': 'Sesión'}.get(section, section)
        inc = re.match(r'^\s*include\s+"([^"]+)"', line)
        if inc:
            rows.extend(collect(path.parent / inc[1], seen))
        inline = re.match(r'^\s*("[^"\n]+"|[\w+.-]+)\s*(.*?)\{\s*([^{}]+)\s*}\s*$', line)
        if inline and ('+' in inline[1] or inline[1].startswith(('XF86', 'Print'))):
            action = inline[3].strip().rstrip(';').strip()
            title = re.search(r'hotkey-overlay-title="([^"]*)"', inline[2])
            if 'hotkey-overlay-title=null' not in inline[2]:
                rows.append(dict(key=inline[1].strip('"').replace('+', ' + '),
                                 label=title[1] if title else action, action=action,
                                 category='Selector de ventanas' if path.name == 'recent-windows.kdl' else section,
                                 source=str(path)))
        bind = re.match(r'^\s*("[^"\n]+"|[\w+.-]+)\s*(.*?)\{\s*$', line)
        if bind and bind[1].strip('"') != 'binds' and ('+' in bind[1] or bind[1].startswith(('XF86', 'Print'))):
            key = bind[1].strip('"')
            metadata = bind[2]
            body = []
            i += 1
            while i < len(lines) and not re.match(r'^\s*}', lines[i]):
                if lines[i].strip() and not lines[i].lstrip().startswith('//'):
                    body.append(lines[i].strip())
                i += 1
            title = re.search(r'hotkey-overlay-title="((?:\\.|[^"\\])*)"', metadata)
            if 'hotkey-overlay-title=null' not in metadata:
                action = ' · '.join(body)
                label = title[1] if title else action
                rows.append(dict(key=key.replace('+', ' + '), label=label,
                                 action=action, category=section, source=str(path)))
        i += 1
    return rows


if __name__ == '__main__':
    try:
        rows = collect(Path.home() / '.config/niri/config.kdl')
        print(json.dumps({'rows': rows, 'error': ''}, ensure_ascii=False))
    except (OSError, UnicodeError) as error:
        print(json.dumps({'rows': [], 'error': str(error)}))
