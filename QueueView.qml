import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Item {
    id: root
    property var queueState: ({queue: []})
    property bool busy: false
    property bool saving: false
    property bool confirmingClear: false
    property bool overwriteRequired: false
    signal back()
    signal add()
    signal load()
    signal action(string command, var value)

    function save(overwrite) {
        root.action("save", {name: mixName.text, overwrite: overwrite})
    }

    Column {
        anchors.fill: parent
        spacing: 10
        Row {
            width: parent.width; spacing: 8
            MixButton { text: "‹ Deck"; onClicked: root.back() }
            Text { width: parent.width - 85; anchors.verticalCenter: parent.verticalCenter; text: (root.queueState.name || "Untitled mixtape") + (root.queueState.dirty ? " *" : ""); textFormat: Text.PlainText; elide: Text.ElideRight; color: Color.foreground; font.family: "monospace"; font.bold: true; font.pixelSize: 13 }
        }
        Row {
            spacing: 8
            MixButton { text: "+ Songs"; onClicked: root.add() }
            MixButton { text: "Load"; onClicked: root.load() }
            MixButton { text: "Save as"; enabled: !root.busy && (root.queueState.count || 0) > 0; onClicked: { root.saving = !root.saving; mixName.text = root.queueState.name || "Untitled mixtape" } }
            MixButton { text: root.confirmingClear ? "Clear all?" : "New"; enabled: !root.busy; onClicked: { if (root.confirmingClear) { root.action("clear", undefined); root.confirmingClear = false } else root.confirmingClear = true } }
        }
        Column {
            visible: root.saving; width: parent.width; spacing: 6
            Controls.TextField {
                id: mixName
                width: parent.width
                placeholderText: "Name your mixtape"
                onTextChanged: root.overwriteRequired = false
                onAccepted: if (!root.busy) root.save(false)
            }
            Row {
                spacing: 8
                MixButton { text: "Save M3U"; enabled: !root.busy; onClicked: root.save(false) }
                MixButton { text: "Replace existing"; visible: root.overwriteRequired; enabled: !root.busy; onClicked: root.save(true) }
                MixButton { text: "Cancel"; onClicked: { root.saving = false; root.overwriteRequired = false } }
            }
            Text { text: "Saved in ~/Music/Mixtapes"; color: Color.foreground; opacity: 0.55; font.family: "monospace"; font.pixelSize: 10 }
        }
        Text {
            text: (root.queueState.count || 0) + " TRACKS · click to play · arrows to reorder"
            color: Color.foreground; opacity: 0.55; font.family: "monospace"; font.pixelSize: 10
        }
        ListView {
            id: tracks
            width: parent.width
            height: Math.max(100, root.height - y - 30)
            clip: true
            model: root.queueState.queue || []
            spacing: 4
            cacheBuffer: 2000
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            delegate: Row {
                required property var modelData
                required property int index
                width: tracks.width; spacing: 4; height: 34
                Controls.ItemDelegate {
                    width: parent.width - 106; height: 34
                    enabled: !root.busy
                    contentItem: Text {
                        text: (modelData.current ? "▶ " : (index + 1) + ". ") + modelData.title
                        textFormat: Text.PlainText; elide: Text.ElideRight
                        color: modelData.current ? Color.accent : (parent.activeFocus ? Color.accent : Color.foreground)
                        font.family: "monospace"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: parent.activeFocus ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent" }
                    onClicked: root.action("play-entry", modelData.id)
                    Controls.ToolTip.visible: hovered
                    Controls.ToolTip.text: modelData.path
                }
                MixButton { implicitWidth: 30; text: "↑"; enabled: !root.busy && index > 0; Accessible.name: "Move track up"; onClicked: root.action("move", {id: modelData.id, delta: -1}) }
                MixButton { implicitWidth: 30; text: "↓"; enabled: !root.busy && index < tracks.count - 1; Accessible.name: "Move track down"; onClicked: root.action("move", {id: modelData.id, delta: 1}) }
                MixButton { implicitWidth: 30; text: "×"; enabled: !root.busy; Accessible.name: "Remove track"; onClicked: root.action("remove", modelData.id) }
            }
            Text { anchors.centerIn: parent; visible: tracks.count === 0; text: "Your next mixtape starts here.\nAdd songs or load a saved mix."; color: Color.foreground; opacity: 0.6; horizontalAlignment: Text.AlignHCenter; font.family: "monospace"; font.pixelSize: 12 }
        }
    }
}
