# Mixtape for Omarchy

A little cassette deck in your bar. Play local music, build named mixtapes,
and watch the reels turn—all in a terminal-inspired, theme-aware floating window.

## Install

Requires **Omarchy's Quickshell shell/plugin system**, **mpv**, and **Python 3**.
Older Omarchy installations using Waybar are not supported.

Install dependencies if needed:

```bash
omarchy pkg add mpv python
```

Install and enable the plugin:

```bash
omarchy plugin add https://github.com/nwohater/MixTape-Omarchy.git --enable
```

The installer lets you choose a bar section. Mixtape defaults to the right.
Move it any time:

```bash
omarchy bar move io.github.nwohater.mixtape --section center
```

Use `left`, `center`, or `right`. Click the cassette icon to open the deck.

### Move it and leave it open

Drag the **MIXTAPE · drag to move** title strip to position the player anywhere
on your desktop. It stays open when you click other applications or bar
widgets. You can also use Hyprland's **Super + left-drag** window gesture.
Close it with **×**, Escape from the deck, or another click on its bar icon.
Closing the window does not stop the music. The window floats on its current
workspace; it is not pinned across workspaces.

## Create your first mixtape

1. Open **Queue → + Songs**.
2. Browse to your music folder, or type its path and press Enter.
3. Select songs using the checkboxes, or choose **Select all**. Selections stay
   checked as you browse between folders; **Select all** adds the current folder's
   files to your selection. **None** clears selections across all folders.
4. Click **Add selected**. **+ Folder** adds all supported audio files in the
   current folder and all its subfolders, visiting albums and tracks alphabetically.
   Directory symlinks are not followed. Embedded playlists are skipped to avoid
   adding their tracks twice.
5. In the queue, click a track to play it. Use **↑ / ↓** to reorder and **×**
   to remove a song. Reordering preserves the current song's playback position.
6. Choose **Save as**, name your mix, and click **Save M3U**.

Saved playlists live in **`~/Music/Mixtapes`**. Saving an existing name asks
whether to replace it. **Load → Saved mixes** reopens a mix; **Eject** can
also browse to playlists stored elsewhere.

The playlist name appears on the cassette label, with the current song and
artist below. An asterisk in the queue header indicates unsaved changes.
**New** offers to clear the current queue so you can build another mix; it
never deletes your audio files or saved playlists.

Adding songs preserves existing playback. Adding to an empty queue prepares
it paused, ready for you to press Play. **Play selected** replaces the queue
and starts playback. From the Load browser, **Save selected** prepares your
selected songs as a paused queue and opens the playlist naming form; enter a
name and click **Save M3U**. M3U, M3U8, and PLS files can also be selected or appended.

## Controls

| Control | Action |
| --- | --- |
| Eject | Browse songs and playlists to load |
| Play / Pause | Toggle playback |
| Stop | Pause and rewind the current song |
| REW / FF click | Previous / next track |
| REW / FF hold | Seek backward / forward ten seconds |
| Volume | Set playback volume |
| Queue | Add, reorder, remove, save, and load tracks |
| Shuffle | Shuffle the queue; toggle off to restore its previous order |
| Repeat | Cycle **off → all → one → off** |
| Space | Play / pause while the deck has focus |
| Left / Right | Seek ten seconds while the deck has focus |
| Escape | Return from the browser/queue, or close the deck |
| Middle-click bar icon | Play / pause |
| Right-click bar icon | Stop |

Shuffle keeps the current song playing and puts it at the start of the
shuffled sequence. Manual reordering turns shuffle off before moving the
selected song. Save captures the queue's current order. Repeat settings are
session controls and are not embedded in saved M3U files.

Playback continues when the player window closes or the shell restarts. Reels resume
spinning when you reopen the deck during playback, and stop when paused.
At the end of the last track with repeat off, Play restarts that track.

The browser supports MP3, FLAC, Ogg, Opus, M4A, AAC, WAV, AIFF, WMA, M3U,
M3U8, and PLS. Existing playlist paths are interpreted by mpv, including
relative paths. Saved M3U files contain absolute paths, so moving the playlist
on the same machine works; moving your music files requires updating it.

## Update

```bash
omarchy plugin update io.github.nwohater.mixtape
omarchy restart shell
```

A plugin rescan normally reloads the UI:

```bash
omarchy-shell shell rescanPlugins
```

If edited QML still shows its old appearance, use `omarchy restart shell` to
clear retained components. The bar briefly disappears; music continues.

## Develop from a checkout

Find the commit you want at
[github.com/nwohater/MixTape-Omarchy/commits/main](https://github.com/nwohater/MixTape-Omarchy/commits/main)
and pin the checkout to its full SHA before running anything from it:

```bash
git clone git@github.com:nwohater/MixTape-Omarchy.git mixtape-plugin
cd mixtape-plugin
git checkout --detach <commit-sha>
python3 install.py --section right
omarchy restart shell
```

`install.py` links this checkout into
`~/.config/omarchy/plugins/io.github.nwohater.mixtape`, backs up `shell.json`, and adds the
widget while preserving other settings. Keep the checkout in place. It
refuses to replace a different installation with the same plugin ID.
If you already use this development installation, skip `omarchy plugin add`.
To update, pick a new commit SHA, then run `git fetch` and
`git checkout --detach <commit-sha>`, and restart the shell.

### Checks

```bash
python3 -m unittest discover -s tests -v
python3 tests/check-qml.py
```

Playback integration tests use real mpv with silent output and temporary
music, playlists, and sockets. They cover transport, queue editing, save/load,
overwrite handling, folder additions, shuffle, and repeat. The QML check
requires a running Wayland session and Omarchy; it checks reel animation
across close/reopen and pause/resume, and loads populated queue/browser views.

### Implementation

- `Widget.qml`: bar widget, deck, and view coordination.
- `Cassette.qml` / `CassetteIcon.qml`: theme-aware cassette artwork and reels.
- `QueueView.qml` / `MusicBrowser.qml`: queue editing and file selection.
- `DeckButton.qml` / `MixButton.qml`: transport and compact controls.
- `player.py`: private mpv process and JSON IPC, with no shell interpolation.
- `install.py`: optional development-checkout installer.

The private mpv process starts when you load or add music. The live queue,
shuffle/repeat settings, and mix name last for the player session. Saved
playlists persist across logout; automatic restoration of the last session
and MPRIS media-key integration are not implemented.

Player logs: `$XDG_RUNTIME_DIR/mixtape/mpv.log`. For diagnostics from a checkout:

```bash
python3 player.py status
python3 player.py quit
```

## Remove

```bash
omarchy plugin remove io.github.nwohater.mixtape
```

To stop playback first, run the `player.py quit` command from your checkout
or the installed plugin directory. Removing the plugin does not remove your
music or saved mixtapes.

## License

MIT — see [LICENSE](LICENSE).
