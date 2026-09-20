#!/usr/bin/env python3
"""Small, shell-free control client for Mixtape's private mpv instance."""
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

AUDIO = {'.mp3', '.flac', '.ogg', '.opus', '.m4a', '.aac', '.wav', '.aiff', '.wma'}
PLAYLISTS = {'.m3u', '.m3u8', '.pls'}
CHILDREN = []


def runtime():
    base = os.environ.get('MIXTAPE_RUNTIME_DIR')
    if not base:
        base = str(Path(os.environ.get('XDG_RUNTIME_DIR', f'/tmp/mixtape-{os.getuid()}')) / 'mixtape')
    path = Path(base)
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.stat().st_uid != os.getuid():
        raise RuntimeError('Playback directory belongs to another user')
    path.chmod(0o700)
    return path


class Client:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.settimeout(3)
        try:
            self.sock.connect(str(path / 'mpv.sock'))
        except Exception:
            self.sock.close()
            raise
        self.stream = self.sock.makefile('rb')
        self.serial = 0

    def close(self):
        self.stream.close()
        self.sock.close()

    def command(self, *args):
        self.serial += 1
        self.sock.sendall((json.dumps({'command': args, 'request_id': self.serial}) + '\n').encode())
        while True:
            line = self.stream.readline()
            if not line:
                raise RuntimeError('Player disconnected')
            reply = json.loads(line)
            if reply.get('request_id') == self.serial:
                if reply.get('error') != 'success':
                    raise RuntimeError(reply.get('error', 'Playback command failed'))
                return reply.get('data')

    def get(self, name, default=None):
        try:
            value = self.command('get_property', name)
            return default if value is None else value
        except RuntimeError:
            return default


def connect(start=False):
    path = runtime()
    with (path / 'startup.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return Client(path)
        except (OSError, RuntimeError):
            if not start:
                return None
        (path / 'mpv.sock').unlink(missing_ok=True)
        args = ['mpv', '--no-config', '--no-video', '--no-terminal', '--idle=yes',
                '--keep-open=yes', '--volume=70', '--input-media-keys=no',
                f'--input-ipc-server={path / "mpv.sock"}']
        if os.environ.get('MIXTAPE_TEST_AUDIO_NULL') == '1':
            args.append('--ao=null')
        with (path / 'mpv.log').open('w') as log:
            process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=log,
                                       stderr=log, start_new_session=True)
            CHILDREN.append(process)
        for _ in range(60):
            if process.poll() is not None:
                raise RuntimeError(f'mpv failed to start; see {path / "mpv.log"}')
            try:
                return Client(path)
            except OSError:
                time.sleep(.05)
        process.terminate()
        process.wait(timeout=3)
        raise RuntimeError('Timed out starting mpv')


def browse(value):
    path = Path(value).expanduser().resolve()
    entries = []
    for item in path.iterdir():
        if item.name.startswith('.'):
            continue
        if item.is_dir() or item.suffix.lower() in AUDIO | PLAYLISTS:
            entries.append({'name': item.name, 'path': str(item), 'directory': item.is_dir()})
    entries.sort(key=lambda item: (not item['directory'], item['name'].casefold()))
    return {'path': str(path), 'parent': str(path.parent), 'entries': entries}


def playlist_directory():
    return Path(os.environ.get('MIXTAPE_PLAYLIST_DIR', str(Path.home() / 'Music' / 'Mixtapes'))).expanduser()


def details(client):
    return client.get('user-data/mixtape', {})


def update_details(client, **values):
    data = details(client)
    data.update(values)
    client.command('set_property', 'user-data/mixtape', data)


def queue(client):
    return client.get('playlist', [])


def find_entry(client, entry_id):
    for index, entry in enumerate(queue(client)):
        if str(entry['id']) == str(entry_id):
            return index
    raise ValueError('That track is no longer in the queue; try again')


def shuffle_queue(client):
    client.command('playlist-shuffle')
    # Start the shuffled sequence at the playing track, without restarting it.
    position = client.get('playlist-pos', -1)
    if position > 0:
        client.command('playlist-move', position, 0)


def select_files(values):
    if not isinstance(values, list) or not values:
        raise ValueError('Select at least one audio file or playlist')
    paths = [Path(value).expanduser().resolve(strict=True) for value in values]
    for path in paths:
        if not path.is_file() or path.suffix.lower() not in AUDIO | PLAYLISTS:
            raise ValueError('Select an audio file or M3U/PLS playlist')
    return paths


def folder_files(value):
    folder = Path(value).expanduser().resolve(strict=True)
    if not folder.is_dir():
        raise ValueError('Select a folder')
    paths = []

    def scan_error(error):
        raise error

    # Do not follow directory symlinks: collections can contain links to ancestors.
    for directory, folders, files in os.walk(folder, onerror=scan_error):
        folders.sort(key=lambda name: (name.casefold(), name))
        for name in sorted(files, key=lambda name: (name.casefold(), name)):
            path = Path(directory) / name
            if path.suffix.lower() in AUDIO and path.is_file():
                paths.append(str(path))
    if not paths:
        raise ValueError('No supported audio files in this folder or its subfolders')
    return select_files(paths)


def save_playlist(client, options):
    name = str(options.get('name', '')).strip()
    if name.lower().endswith(('.m3u', '.m3u8')):
        name = name.rsplit('.', 1)[0].strip()
    if not name or len(name) > 120 or any(c in name for c in '/\\\r\n\0') or name in {'.', '..'}:
        raise ValueError('Use a playlist name of 1–120 characters without slashes or line breaks')
    entries = queue(client)
    if not entries:
        raise ValueError('Add some songs before saving a playlist')
    lines = ['#EXTM3U']
    for entry in entries:
        filename = entry['filename']
        if '\n' in filename or '\r' in filename:
            raise ValueError('M3U cannot store filenames containing line breaks')
        if '://' not in filename:
            filename = str((Path(client.get('working-directory', '/')) / filename).resolve())
        lines.append(filename)
    directory = playlist_directory()
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / (name + '.m3u')
    fd, temporary = tempfile.mkstemp(prefix='.mixtape-', dir=directory)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as output:
            output.write('\n'.join(lines) + '\n')
        if options.get('overwrite') is True:
            os.replace(temporary, destination)
        else:
            try:
                os.link(temporary, destination)
            except FileExistsError:
                return {'error': f'“{name}” already exists. Replace it or choose another name.', 'overwriteRequired': True}
    finally:
        Path(temporary).unlink(missing_ok=True)
    update_details(client, name=name, dirty=False)
    return None


def status(client):
    if client is None:
        return {'loaded': False, 'paused': True, 'title': 'Insert a mixtape', 'volume': 70,
                'queue': [], 'count': 0, 'name': 'Untitled mixtape', 'shuffle': False, 'repeat': 'off'}
    metadata = client.get('metadata', {})
    data = details(client)
    entries = queue(client)
    return {'loaded': bool(client.get('path', '')), 'paused': client.get('pause', True),
            'ended': client.get('eof-reached', False),
            'title': metadata.get('title') or metadata.get('TITLE') or client.get('media-title', 'Insert a mixtape'),
            'artist': metadata.get('artist') or metadata.get('ARTIST', ''),
            'position': client.get('time-pos', 0), 'duration': client.get('duration', 0),
            'volume': client.get('volume', 70), 'index': client.get('playlist-pos', -1),
            'count': len(entries), 'name': data.get('name', 'Untitled mixtape'),
            'dirty': data.get('dirty', False), 'shuffle': data.get('shuffle', False),
            'repeat': 'one' if client.get('loop-file', False) not in (False, 'no', 0, None) else
                      'all' if client.get('loop-playlist', False) not in (False, 'no', 0, None) else 'off',
            'queue': [{'id': entry['id'], 'title': entry.get('title') or Path(entry['filename']).name,
                       'path': entry['filename'], 'current': entry.get('current', False)} for entry in entries]}


def execute(args):
    action = args[0] if args else 'status'
    if action == 'browse':
        return browse(args[1] if len(args) > 1 else str(Path.home()))
    if action == 'library':
        directory = playlist_directory()
        return browse(str(directory)) if directory.exists() else {
            'path': str(directory), 'parent': str(directory.parent), 'entries': []}
    if action not in {'status', 'load', 'load-many', 'build-many', 'append', 'add-folder', 'save', 'play-entry',
                      'remove', 'move', 'clear', 'shuffle', 'repeat',
                      'toggle', 'stop', 'previous', 'next', 'seek', 'volume', 'quit'}:
        raise ValueError('Unknown player action')
    selected = []
    if action in {'load', 'load-many', 'build-many', 'append'}:
        selected = select_files([args[1]] if action == 'load' else json.loads(args[1]))
    elif action == 'add-folder':
        selected = folder_files(args[1])
    client = connect(start=bool(selected))
    if client is None:
        if action not in {'status', 'quit'}:
            raise RuntimeError('Eject to choose a file or playlist first')
        return status(None)
    try:
        if selected:
            replace = action in {'load', 'load-many', 'build-many'}
            was_empty = not queue(client)
            shuffled = details(client).get('shuffle', False)
            if shuffled:
                client.command('playlist-unshuffle')
            if action == 'build-many':
                client.command('set_property', 'pause', True)
            for index, path in enumerate(selected):
                mode = 'replace' if replace and index == 0 else 'append'
                client.command('loadlist' if path.suffix.lower() in PLAYLISTS else 'loadfile', str(path), mode)
            if replace or was_empty:
                if not replace:
                    client.command('set_property', 'playlist-pos', 0)
                client.command('set_property', 'pause', not replace or action == 'build-many')
                name = selected[0].stem if len(selected) == 1 and selected[0].suffix.lower() in PLAYLISTS else 'Untitled mixtape'
                update_details(client, name=name, dirty=name == 'Untitled mixtape', shuffle=False)
            else:
                update_details(client, dirty=True)
                if shuffled:
                    shuffle_queue(client)
        elif action == 'save':
            conflict = save_playlist(client, json.loads(args[1]))
            if conflict:
                return conflict
        elif action == 'play-entry':
            client.command('set_property', 'playlist-pos', find_entry(client, args[1]))
            client.command('set_property', 'pause', False)
        elif action == 'remove':
            client.command('playlist-remove', find_entry(client, args[1]))
            update_details(client, dirty=True)
        elif action == 'move':
            options = json.loads(args[1])
            if details(client).get('shuffle', False):
                client.command('playlist-unshuffle')
                update_details(client, shuffle=False)
            index = find_entry(client, options['id'])
            target = index + int(options['delta'])
            if 0 <= target < len(queue(client)):
                client.command('playlist-move', index, target + (1 if target > index else 0))
                update_details(client, dirty=True)
        elif action == 'clear':
            client.command('stop')
            client.command('playlist-clear')
            update_details(client, name='Untitled mixtape', dirty=False, shuffle=False)
        elif action == 'shuffle':
            shuffled = details(client).get('shuffle', False)
            if shuffled:
                client.command('playlist-unshuffle')
            else:
                shuffle_queue(client)
            update_details(client, shuffle=not shuffled, dirty=True)
        elif action == 'repeat':
            mode = args[1]
            if mode not in {'off', 'all', 'one'}:
                raise ValueError('Repeat must be off, all, or one')
            client.command('set_property', 'loop-file', 'inf' if mode == 'one' else 'no')
            client.command('set_property', 'loop-playlist', 'inf' if mode == 'all' else 'no')
        elif action == 'toggle':
            if client.get('eof-reached', False):
                client.command('seek', 0, 'absolute')
                client.command('set_property', 'pause', False)
            else:
                client.command('cycle', 'pause')
        elif action == 'stop':
            client.command('set_property', 'pause', True)
            client.command('seek', 0, 'absolute')
        elif action in {'previous', 'next'}:
            index = client.get('playlist-pos', 0)
            count = client.get('playlist-count', 0)
            target = index + (-1 if action == 'previous' else 1)
            if 0 <= target < count:
                client.command('set_property', 'playlist-pos', target)
            elif count and client.get('loop-playlist', False) not in (False, 'no', 0, None):
                client.command('set_property', 'playlist-pos', target % count)
            elif action == 'previous':
                client.command('seek', 0, 'absolute')
        elif action == 'seek':
            client.command('seek', max(-3600, min(3600, float(args[1]))), 'relative')
        elif action == 'volume':
            client.command('set_property', 'volume', max(0, min(100, float(args[1]))))
        elif action == 'quit':
            client.command('quit')
            for process in CHILDREN:
                process.wait(timeout=3)
            CHILDREN.clear()
            return status(None)
        return status(client)
    finally:
        client.close()


def run(args):
    # Serialize queue edits from multiple monitors; entry IDs prevent stale-row edits.
    with (runtime() / 'commands.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return execute(args)


if __name__ == '__main__':
    try:
        print(json.dumps(run(sys.argv[1:])))
    except (OSError, RuntimeError, ValueError, IndexError) as error:
        print(json.dumps({'error': str(error)}))
        sys.exit(1)
