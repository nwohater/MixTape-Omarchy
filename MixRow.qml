import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

ItemDelegate {
    id: root
    hoverEnabled: true
    leftPadding: 8; rightPadding: 8
    background: Rectangle {
        radius: 3
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, root.down ? 0.15 : root.hovered ? 0.08 : 0)
        border.color: root.activeFocus ? Commons.Color.accent : "transparent"
    }
}
