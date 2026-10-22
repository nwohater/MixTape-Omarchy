import QtQuick
import QtQuick.Controls
import qs.Commons
// The built-in `Color` value type shadows the qs.Commons `Color` singleton
// in this context (same as the other Mixtape components), so unqualified
// `Color.x` is silently undefined. Qualify through the module alias.
import qs.Commons as Commons

Button {
    id: root
    property bool highlightedMix: false
    implicitHeight: 30
    implicitWidth: Math.max(48, label.implicitWidth + 18)
    hoverEnabled: true
    contentItem: Text {
        id: label
        text: root.text
        color: root.highlightedMix ? Commons.Color.accent : Commons.Color.foreground
        opacity: root.enabled ? 1 : 0.35
        font.family: "monospace"; font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 3
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, root.down ? 0.15 : root.hovered ? 0.08 : 0.03)
        border.color: root.activeFocus || root.highlightedMix ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.25)
    }
}
