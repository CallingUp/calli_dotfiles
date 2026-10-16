#!/usr/bin/env python3
"""Compare Rust against the original palette, without touching the live theme."""
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "config/quickshell/minflair-niri/Scripts/theme"
sys.path.insert(0, str(THEME))
from theme_extractors.palette import generate_palette
from theme_extractors.magick_utils import extract_histogram_colors

BIN = ROOT / "tools/haku-info/target/release/haku-info"

def rust_palette(hist):
    text = "\n".join(f"{count}: (0,0,0) {color}" for color, count in hist.items())
    return json.loads(subprocess.check_output([BIN, "theme-palette"], input=text, text=True))

class ThemeParity(unittest.TestCase):
    def compare(self, hist):
        dark, light = generate_palette(hist)
        self.assertEqual(rust_palette(hist), {"dark": dark, "light": light})

    def test_random_palettes(self):
        rng = random.Random(42)
        for _ in range(200):
            hist = {f"#{rng.randrange(0x1000000):06x}": rng.randrange(1, 10000) for _ in range(32)}
            self.compare(hist)

    def test_grayscale_and_ties(self):
        for hist in [
            {"#000000": 100}, {"#ffffff": 100}, {"#808080": 100},
            {"#ff0000": 100, "#00ff00": 100, "#0000ff": 100},
            {"#808080": 9999, "#818080": 100},
            {"#000000": 9999, "#ff0000": 1},
        ]:
            self.compare(hist)

    def test_real_image_palette(self):
        image = Path.home() / "Pictures/fastfetch-icon/icon.png"
        if not image.exists(): self.skipTest("Local sample unavailable")
        self.compare(extract_histogram_colors(str(image)))

    def test_generator_preserves_manual_scheme(self):
        image = Path.home() / "Pictures/fastfetch-icon/icon.png"
        if not image.exists(): self.skipTest("Local sample unavailable")
        with tempfile.TemporaryDirectory(prefix="haku-theme-test-") as home:
            env = dict(os.environ, HOME=home)
            subprocess.run([BIN, "theme", image, "false"], env=env, check=True, capture_output=True)
            cache = Path(home) / ".cache/quickshell"
            self.assertFalse((cache / "colorscheme.json").exists())
            manual = {"generateFromWallpaper": False, "wallpaperIsDark": False, "accent": "#123456"}
            (cache / "colorscheme.json").write_text(json.dumps(manual))
            subprocess.run([BIN, "theme", image], env=env, check=True, capture_output=True)
            self.assertEqual(json.loads((cache / "colorscheme.json").read_text()), manual)
            active = json.loads((cache / "wallpaper_colorscheme.json").read_text())
            light = json.loads((cache / "wallpaper_colorscheme_light.json").read_text())
            self.assertEqual(active, dict(light, wallpaperIsDark=False))
            subprocess.run([BIN, "theme", image, "true"], env=env, check=True, capture_output=True)
            self.assertEqual(json.loads((cache / "colorscheme.json").read_text()), active)
            self.assertFalse(list(cache.glob("*.tmp")))

    def test_full_generator_parity(self):
        image = Path.home() / "Pictures/fastfetch-icon/icon.png"
        if not image.exists(): self.skipTest("Local sample unavailable")
        with tempfile.TemporaryDirectory(prefix="haku-theme-parity-") as home:
            env = dict(os.environ, HOME=home)
            results = []
            for cmd in [[sys.executable, "-B", THEME / "generate_theme.py"], [BIN, "theme"]]:
                subprocess.run(cmd + [image, "true"], env=env, check=True, capture_output=True)
                cache = Path(home) / ".cache/quickshell"
                results.append({p.name: json.loads(p.read_text()) for p in cache.glob("*.json")})
            self.assertEqual(results[0], results[1])

if __name__ == "__main__": unittest.main()
