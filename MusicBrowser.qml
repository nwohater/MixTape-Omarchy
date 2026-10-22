import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
// The built-in `Color` value type shadows the qs.Commons `Color` singleton
// in this context, so unqualified `Color.x` is silently undefined.
// Qualify through the module alias — see the long note in Widget.qml.
import qs.Commons as Commons

Item {
    id: root
    property var listing: ({path: "", parent: "", entries: []})
    property var albums: ({path: "", entries: []})
    property var selected: []
    property bool busy: false
    property bool adding: false
    property bool albumView: false
    property string libraryRoot: ""
    readonly property bool tabsVisible: !root.adding
    property bool searchTyping: false
    property string searchQuery: ""
    readonly property bool searchActive: !root.searchTyping && root.searchQuery !== ""
    signal back()
    signal browse(string path)
    signal library()
    signal albumsRequested()
    signal refocus()
    signal submit(string command, var value)

    property var displayEntries: {
        var entries = []
        if (!root.adding && root.listing.path && root.listing.path !== root.libraryRoot) {
            entries.push({name: "..", path: root.listing.parent, directory: true})
        }
        for (var i = 0; i < root.listing.entries.length; i++) entries.push(root.listing.entries[i])
        return root.filterBy(entries)
    }
    property var albumEntries: {
        var entries = []
        var list = (root.albums && root.albums.entries) ? root.albums.entries : []
        for (var i = 0; i < list.length; i++) entries.push(list[i])
        return root.filterBy(entries)
    }

    function filterBy(entries) {
        var q = root.searchQuery.trim().toLowerCase()
        if (!q) return entries
        return entries.filter(function(e) { return e.name === ".." || e.name.toLowerCase().indexOf(q) !== -1 })
    }

    function resetSelection() { selected = [] }
    function select(path, checked) {
        var next = selected.filter(function(p) { return p !== path })
        if (checked) next.push(path)
        selected = next
    }
    function showTab(album) {
        if (album === root.albumView) return
        root.albumView = album
        if (album) root.albumsRequested()
    }
    function toggleTabs() { root.showTab(!root.albumView) }
    function startSearch() {
        if (!root.tabsVisible) return
        root.searchTyping = true
        searchField.text = root.searchQuery
        Qt.callLater(function() { searchField.forceActiveFocus() })
    }
    function confirmSearch() {
        root.searchTyping = false
        root.refocus()
    }
    function cancelSearch() {
        root.searchTyping = false
        root.searchQuery = ""
        searchField.text = ""
        root.refocus()
    }
    function clearSearch() {
        root.searchQuery = ""
        searchField.text = ""
        root.refocus()
    }
    onListingChanged: resetSelection()
    onAddingChanged: if (root.adding) root.albumView = false

    Column {
        anchors.fill: parent; spacing: 10
        Row {
            visible: root.tabsVisible
            spacing: 8
            MixButton {
                id: customTabButton
                objectName: "browserTabCustom"
                text: "Custom"
                highlightedMix: !root.albumView
                Accessible.name: "Custom tapes"
                onClicked: root.showTab(false)
            }
            MixButton {
                id: albumTabButton
                objectName: "browserTabAlbums"
                text: "Albums"
                highlightedMix: root.albumView
                Accessible.name: "Album tapes"
                onClicked: root.showTab(true)
            }
        }
        Row {
            spacing: 8
            MixButton { text: "‹ Back"; visible: root.adding; onClicked: root.back() }
            MixButton { text: "↑ Up"; visible: root.adding; enabled: !root.busy; onClicked: root.browse(root.listing.parent) }
            MixButton { text: "Saved mixes"; visible: root.adding; enabled: !root.busy; onClicked: root.library() }
        }
        Controls.TextField {
            visible: root.adding
            width: parent.width
            text: root.listing.path
            placeholderText: "Directory path — press Enter"
            onAccepted: root.browse(text)
        }
        Row {
            visible: root.adding
            spacing: 8
            MixButton {
                text: "Select all"
                enabled: !root.busy
                onClicked: root.selected = root.listing.entries.filter(function(e) { return !e.directory }).map(function(e) { return e.path })
            }
            MixButton { text: "None"; onClicked: root.resetSelection() }
            MixButton {
                text: "+ Folder"
                enabled: !root.busy
                onClicked: root.submit("add-folder", root.listing.path)
                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: "Add audio files in this folder (not subfolders)"
            }
        }
        ListView {
            id: files
            objectName: "fileList"
            visible: !root.albumView
            width: parent.width; height: Math.max(100, root.height - y - (root.adding ? 76 : 60)); clip: true
            model: root.displayEntries
            cacheBuffer: 2000
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            delegate: Row {
                required property var modelData
                width: files.width; height: 36
                Controls.CheckBox {
                    width: 34; height: 36
                    visible: root.adding && !modelData.directory
                    enabled: !root.busy
                    checked: root.selected.indexOf(modelData.path) !== -1
                    Accessible.name: "Select " + modelData.name
                    onClicked: root.select(modelData.path, checked)
                }
                Controls.ItemDelegate {
                    width: parent.width - (root.adding && !modelData.directory ? 34 : 0); height: 36
                    enabled: !root.busy
                    contentItem: Text {
                        text: (modelData.directory ? "▸  " : "") + modelData.name
                        textFormat: Text.PlainText; elide: Text.ElideMiddle
                        color: parent.activeFocus ? Commons.Color.accent : Commons.Color.foreground; font.family: "monospace"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: parent.activeFocus ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12) : "transparent" }
                    onClicked: {
                        if (modelData.directory) root.browse(modelData.path)
                        else if (root.adding) root.select(modelData.path, root.selected.indexOf(modelData.path) === -1)
                        else root.submit("load-many", [modelData.path])
                    }
                }
            }
            Text { anchors.centerIn: parent; visible: !root.busy && files.count === 0; text: "No music here yet."; color: Commons.Color.foreground; font.family: "monospace"; font.pixelSize: 12 }
        }
        Text {
            visible: root.albumView
            text: "ALBUMS · " + root.albums.path
            color: Commons.Color.foreground; opacity: 0.55; font.family: "monospace"; font.pixelSize: 10
        }
        ListView {
            id: albumsList
            objectName: "albumList"
            visible: root.albumView
            width: parent.width; height: Math.max(100, root.height - y - (root.adding ? 76 : 60)); clip: true
            model: root.albumEntries
            cacheBuffer: 2000
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            delegate: Row {
                required property var modelData
                width: albumsList.width; height: 36
                Controls.ItemDelegate {
                    width: parent.width; height: 36
                    enabled: !root.busy
                    contentItem: Text {
                        text: "▸  " + modelData.name + "   · " + (modelData.trackCount || 0) + " tracks"
                        textFormat: Text.PlainText; elide: Text.ElideMiddle
                        color: parent.activeFocus ? Commons.Color.accent : Commons.Color.foreground; font.family: "monospace"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: parent.activeFocus ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12) : "transparent" }
                    onClicked: root.submit("load-album", modelData.path)
                }
            }
            Text { anchors.centerIn: parent; visible: !root.busy && albumsList.count === 0; text: "No album folders with music in this directory."; color: Commons.Color.foreground; font.family: "monospace"; font.pixelSize: 12 }
        }
        Row {
            visible: root.adding
            spacing: 8
            MixButton {
                text: (root.adding ? "Add selected (" : "Play selected (") + root.selected.length + ")"
                enabled: !root.busy && root.selected.length > 0
                highlightedMix: true
                onClicked: root.submit(root.adding ? "append" : "load-many", root.selected)
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.adding ? "Keeps current playback" : "Replaces current queue"; color: Commons.Color.foreground; opacity: 0.55; font.pixelSize: 10 }
        }
    }

    Rectangle {
        id: searchLine
        objectName: "searchLine"
        visible: root.tabsVisible
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 30
        color: root.searchTyping ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.16) : "transparent"
        border.width: 1
        border.color: (root.searchTyping || root.searchActive) ? Commons.Color.accent
            : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.25)

        Controls.TextField {
            id: searchField
            objectName: "searchField"
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            visible: root.searchTyping
            color: Commons.Color.foreground
            font.family: "monospace"
            font.pixelSize: 12
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: "Filter…  Enter to confirm · Esc to cancel"
            background: Item {}
            onTextChanged: if (root.searchTyping) root.searchQuery = text
            onAccepted: root.confirmSearch()
            Keys.onReturnPressed: function(event) { event.accepted = true; root.confirmSearch() }
            Keys.onEnterPressed: function(event) { event.accepted = true; root.confirmSearch() }
            Keys.onEscapePressed: function(event) { event.accepted = true; root.cancelSearch() }
        }
        Text {
            visible: !root.searchTyping
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.searchActive ? "⌕  " + root.searchQuery + "   ·  Esc to clear" : "Press / to filter"
            textFormat: Text.PlainText
            color: root.searchActive ? Commons.Color.accent : Commons.Color.foreground
            opacity: root.searchActive ? 1 : 0.45
            font.family: "monospace"; font.pixelSize: 11
            verticalAlignment: Text.AlignVCenter
        }
    }
}
