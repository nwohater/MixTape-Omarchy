"""Integration tests use real mpv with silent output and a private socket."""
import importlib.util
import os
from pathlib import Path
import tempfile
import time
import unittest
import wave
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('player', Path(__file__).parents[1] / 'player.py')
player = importlib.util.module_from_spec(spec)
spec.loader.exec_module(player)


class PlaybackTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='mixtape-test-')
        self.path = Path(self.temp.name)
        self.env = patch.dict(os.environ, {'MIXTAPE_RUNTIME_DIR': str(self.path / 'runtime'), 'MIXTAPE_TEST_AUDIO_NULL': '1', 'MIXTAPE_PLAYLIST_DIR': str(self.path / 'mixes')})
        self.env.start()
        self.track = self.path / 'Track "one" $(literal).wav'
        self.second = self.path / 'Track two.wav'
        for path in (self.track, self.second):
            with wave.open(str(path), 'wb') as audio:
                audio.setnchannels(1)
                audio.setsampwidth(2)
                audio.setframerate(8000)
                audio.writeframes(b'\0\0' * 8000 * 30)

    def tearDown(self):
        try:
            player.run(['quit'])
        finally:
            self.env.stop()
            self.temp.cleanup()

    def wait_for(self, predicate):
        for _ in range(60):
            state = player.run(['status'])
            if predicate(state):
                return state
            time.sleep(.05)
        self.fail(f'Timed out waiting for player state: {state}')

    def test_transport_and_playlist(self):
        self.assertFalse(player.run(['status'])['loaded'])
        player.run(['load', str(self.track)])
        state = self.wait_for(lambda s: s.get('duration', 0) > 0)
        self.assertTrue(state['loaded'])
        self.assertFalse(state['paused'])
        self.assertIn('$(literal)', state['title'])
        self.assertTrue(player.run(['toggle'])['paused'])
        player.run(['seek', '10'])
        self.wait_for(lambda s: s.get('position', 0) >= 9)
        self.assertEqual(player.run(['volume', '500'])['volume'], 100)
        player.run(['stop'])
        self.wait_for(lambda s: s['paused'] and s['position'] < 1)
        playlist = self.path / 'My mix.m3u'
        playlist.write_text(f'#EXTM3U\n{self.track.name}\n{self.second.name}\n')
        player.run(['load', str(playlist)])
        self.wait_for(lambda s: s.get('count') == 2 and s.get('index') == 0)
        player.run(['next'])
        self.wait_for(lambda s: s.get('index') == 1 and 'Track two' in s.get('title', ''))
        player.run(['next'])
        self.assertEqual(player.run(['status'])['index'], 1)
        player.run(['previous'])
        self.wait_for(lambda s: s.get('index') == 0)

    def test_browser_and_invalid_selection(self):
        (self.path / 'Albums').mkdir()
        (self.path / 'ignore.txt').write_text('not music')
        listing = player.browse(str(self.path))
        self.assertTrue(listing['entries'][0]['directory'])
        self.assertNotIn('ignore.txt', [entry['name'] for entry in listing['entries']])
        with self.assertRaises(ValueError):
            player.run(['load', str(self.path / 'ignore.txt')])
        with self.assertRaises(FileNotFoundError):
            player.run(['load', str(self.path / 'missing.mp3')])

    def test_queue_edit_and_save_roundtrip(self):
        import json
        player.run(['append', json.dumps([str(self.track), str(self.second)])])
        state = self.wait_for(lambda s: s.get('count') == 2 and s.get('loaded'))
        self.assertTrue(state['paused'])  # Building an empty mix does not autoplay.
        first, second = [entry['id'] for entry in state['queue']]
        player.run(['play-entry', str(first)])
        self.wait_for(lambda s: s['loaded'] and not s['paused'])
        player.run(['seek', '10'])
        self.wait_for(lambda s: s.get('position', 0) >= 9)
        moved = player.run(['move', json.dumps({'id': first, 'delta': 1})])
        self.assertEqual([e['id'] for e in moved['queue']], [second, first])
        self.assertGreaterEqual(moved['position'], 9)
        self.assertFalse(moved['paused'])
        saved = player.run(['save', json.dumps({'name': 'Late Night Mix'})])
        self.assertEqual(saved['name'], 'Late Night Mix')
        destination = self.path / 'mixes' / 'Late Night Mix.m3u'
        original = destination.read_text()
        self.assertEqual(original.splitlines()[1:], [str(self.second), str(self.track)])
        player.run(['remove', str(second)])
        conflict = player.run(['save', json.dumps({'name': 'Late Night Mix'})])
        self.assertTrue(conflict['overwriteRequired'])
        self.assertEqual(destination.read_text(), original)
        player.run(['save', json.dumps({'name': 'Late Night Mix', 'overwrite': True})])
        self.assertEqual(destination.read_text().splitlines()[1:], [str(self.track)])
        player.run(['clear'])
        self.wait_for(lambda s: s['count'] == 0 and not s['loaded'])
        player.run(['load', str(destination)])
        state = self.wait_for(lambda s: s['count'] == 1 and s.get('loaded'))
        self.assertEqual(state['name'], 'Late Night Mix')
        self.assertEqual(state['queue'][0]['path'], str(self.track))
        self.assertIn('Late Night Mix.m3u', [e['name'] for e in player.run(['library'])['entries']])
        with self.assertRaises(ValueError):
            player.run(['save', json.dumps({'name': '../escape'})])
        with self.assertRaises(ValueError):
            player.run(['remove', str(second)])

    def test_shuffle_repeat_and_folder(self):
        import json
        player.run(['load', str(self.track)])
        self.wait_for(lambda s: s['loaded'])
        player.run(['toggle'])
        state = player.run(['add-folder', str(self.path)])
        self.assertEqual(state['count'], 3)
        self.assertTrue(state['paused'])
        original = [e['id'] for e in state['queue']]
        state = player.run(['shuffle'])
        self.assertTrue(state['shuffle'])
        self.assertCountEqual([e['id'] for e in state['queue']], original)
        self.assertEqual(state['index'], 0)
        state = player.run(['shuffle'])
        self.assertFalse(state['shuffle'])
        self.assertEqual([e['id'] for e in state['queue']], original)
        for mode in ('all', 'one', 'off'):
            self.assertEqual(player.run(['repeat', mode])['repeat'], mode)
        player.run(['repeat', 'all'])
        player.run(['play-entry', str(original[-1])])
        player.run(['next'])
        self.wait_for(lambda s: s['index'] == 0)
        player.run(['load-many', json.dumps([str(self.second), str(self.track)])])
        self.wait_for(lambda s: s['count'] == 2 and s['queue'][0]['path'] == str(self.second))

    def test_recursive_folder(self):
        collection = self.path / 'George Jones'
        disc = collection / 'Album B' / 'Disc 1'
        disc.mkdir(parents=True)
        album = collection / 'Album A'
        album.mkdir()
        first = album / '01 Song.wav'
        second = disc / '02 Song.WAV'
        first.write_bytes(self.track.read_bytes())
        second.write_bytes(self.second.read_bytes())
        (album / 'cover.jpg').write_text('ignored')
        (album / 'album.m3u').write_text(str(first))
        (disc / 'loop').symlink_to(collection, target_is_directory=True)
        player.run(['load', str(self.track)])
        self.wait_for(lambda s: s.get('duration', 0) > 0)
        player.run(['seek', '10'])
        before = self.wait_for(lambda s: s.get('position', 0) >= 9)
        state = player.run(['add-folder', str(collection)])
        self.assertEqual([e['path'] for e in state['queue']],
                         [str(self.track), str(first), str(second)])
        self.assertEqual(state['queue'][0]['id'], before['queue'][0]['id'])
        self.assertFalse(state['paused'])
        self.assertGreaterEqual(state['position'], 9)
        empty = collection / 'Empty'
        empty.mkdir()
        with self.assertRaisesRegex(ValueError, 'No supported audio'):
            player.run(['add-folder', str(empty)])
        self.assertEqual(player.run(['status'])['count'], 3)

    def test_build_selection_and_save(self):
        import json
        album = self.path / 'Another album'
        album.mkdir()
        other = album / 'Song.wav'
        other.write_bytes(self.second.read_bytes())
        player.run(['load', str(self.second)])
        self.wait_for(lambda s: s.get('loaded') and not s['paused'])
        paths = [str(self.track), str(other)]
        player.run(['build-many', json.dumps(paths)])
        state = self.wait_for(lambda s: s['count'] == 2 and s.get('loaded'))
        self.assertTrue(state['paused'])
        self.assertEqual([e['path'] for e in state['queue']], paths)
        player.run(['save', json.dumps({'name': 'Across albums'})])
        self.assertEqual((self.path / 'mixes' / 'Across albums.m3u').read_text().splitlines()[1:], paths)


if __name__ == '__main__':
    unittest.main()
