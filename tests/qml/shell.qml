import QtQuick
import Quickshell
import "../../" as Mixtape

// Run through the isolated harness described in tests/check-qml.py.
ShellRoot {
    property real before: 0
    property real stopped: 0
    property var reel: null
    property int phase: 0
    function findReel(item) {
        if (item.objectName === "cassetteReel0") return item
        for (var i = 0; i < item.children.length; i++) {
            var found = findReel(item.children[i])
            if (found) return found
        }
        return null
    }
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    Item {
        Mixtape.Cassette { id: tape; width: 396; height: 210; playing: true }
        Mixtape.QueueView {
            id: queueView
            width: 396; height: 510
            queueState: ({name: "Test mix", count: 2, queue: [
                {id: 10, title: "Track one", path: "/tmp/one.wav", current: true},
                {id: 11, title: "Track two", path: "/tmp/two.wav", current: false}
            ]})
        }
        Mixtape.MusicBrowser {
            id: browser
            width: 396; height: 510
            listing: ({path: "/tmp", parent: "/", entries: [
                {name: "Songs", path: "/tmp/Songs", directory: true},
                {name: "Track one.wav", path: "/tmp/one.wav", directory: false}
            ]})
        }
    }
    Timer {
        interval: 180; repeat: true; running: true
        onTriggered: {
            phase++
            if (phase === 1) {
                queueView.beginSave()
                check(queueView.saving && !queueView.overwriteRequired, "save form opens for selected songs")
                var original = browser.listing
                browser.select('/tmp/one.wav', true)
                browser.listing = {path: '/tmp/Songs', parent: '/tmp', entries: [
                    {name: 'Two.wav', path: '/tmp/Songs/two.wav', directory: false}
                ]}
                check(browser.selected.length === 1, 'selection survives entering a folder')
                browser.selectAll()
                browser.selectAll()
                check(browser.selected.length === 2, 'select all preserves other folders without duplicates')
                browser.listing = original
                check(browser.selected.indexOf('/tmp/one.wav') !== -1 && browser.selected.length === 2,
                      'selection survives navigating up')
                browser.select('/tmp/one.wav', false)
                check(browser.selected.length === 1 && browser.selected[0] === '/tmp/Songs/two.wav',
                      'deselect keeps other folders selected')
                browser.resetSelection()
                check(browser.selected.length === 0, 'clear removes selections across folders')
                reel = findReel(tape)
                check(reel !== null, "reel exists")
                before = reel.rotation
            } else if (phase === 2) {
                check(reel.rotation !== before, "spins during playback")
                tape.animationVisible = false
            } else if (phase === 3) {
                tape.animationVisible = true
                before = reel.rotation
            } else if (phase === 4) {
                check(reel.rotation !== before, "resumes after reopening")
                tape.playing = false
            } else if (phase === 5) {
                stopped = reel.rotation
            } else if (phase === 6) {
                check(reel.rotation === stopped, "stops while paused")
                tape.playing = true
                before = reel.rotation
            } else if (phase === 7) {
                check(reel.rotation !== before, "resumes after pause")
                console.log("PASS: reel close/reopen and pause/resume; populated queue and browser loaded")
                Qt.quit()
            }
        }
    }
}
