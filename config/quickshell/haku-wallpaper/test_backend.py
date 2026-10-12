from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

backend = runpy.run_path(str(Path(__file__).resolve().parents[3] / 'scripts/bin/haku-wallpaper-selector'))


class WallpaperTests(unittest.TestCase):
    def test_only_official_https_urls(self):
        valid = backend['allowed_url']
        self.assertEqual(valid('https://th.wallhaven.cc/small/ab/abcdef.jpg'), 'https://th.wallhaven.cc/small/ab/abcdef.jpg')
        for url in ['http://wallhaven.cc/a', 'https://wallhaven.cc.evil.org/a', 'file:///tmp/a', 'https://user:password@wallhaven.cc/a']:
            with self.assertRaises(ValueError): valid(url)

    def test_safe_search_defaults_and_metadata(self):
        payload = {'data': [{'id':'abcdef', 'resolution':'1920x1080', 'thumbs':{'small':'https://th.wallhaven.cc/a.jpg'}, 'path':'https://w.wallhaven.cc/full/a.jpg'}], 'meta':{'total':42, 'last_page':2}}
        import json
        with patch.dict(backend['search'].__globals__, fetch=lambda url, maximum: self.assert_defaults(url, json.dumps(payload).encode())):
            result = backend['search']('test', 1)
        self.assertEqual(result['rows'][0]['kind'], 'web')
        self.assertEqual(result['total'], 42)

    def assert_defaults(self, url, response):
        for expected in ['sorting=favorites', 'purity=100', 'categories=111', 'atleast=1920x1080', 'ratios=16x9']:
            self.assertIn(expected, url)
        return response

    def test_gallery_path_validation(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            gallery = directory / 'gallery'
            gallery.mkdir()
            photo = gallery / 'test.png'
            photo.touch()
            outside = directory / 'outside.png'
            outside.touch()
            with patch.dict(backend['local_path'].__globals__, WALLS=gallery):
                self.assertEqual(backend['local_path'](str(photo)), photo)
                with self.assertRaises(ValueError): backend['local_path'](str(outside))

    def test_current_wallpaper_is_not_reapplied(self):
        with tempfile.TemporaryDirectory() as temp:
            state = Path(temp)
            photo = state / 'test.png'
            photo.touch()
            namespace = backend['apply'].__globals__
            with patch.dict(namespace, STATE=state, local_path=lambda _: photo, current=lambda: str(photo)), patch('subprocess.Popen') as popen:
                result = backend['apply']({'kind':'local', 'path':str(photo)})
            self.assertTrue(result['unchanged'])
            popen.assert_not_called()

    def test_active_wallpaper_cannot_be_trashed(self):
        photo = Path('/fake/gallery/test.png')
        with patch.dict(backend['worker'].__globals__, local_path=lambda _: photo, current=lambda: str(photo)), patch('subprocess.run') as run:
            with self.assertRaises(ValueError): backend['worker']({'action':'trash', 'item':{'path':str(photo)}})
        run.assert_not_called()

    def test_recycled_slots_are_continuous_and_unique(self):
        for center in range(-20, 20):
            slots = [center + ((i - center % 7 + 3) % 7) - 3 for i in range(7)]
            self.assertEqual(sorted(slots), list(range(center - 3, center + 4)))
            self.assertIn(center, slots)


if __name__ == '__main__': unittest.main()
