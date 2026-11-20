import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

TextField {
    id: root
    implicitHeight: 32
    color: Commons.Color.foreground
    placeholderTextColor: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
    selectionColor: Commons.Color.accent
    selectedTextColor: Commons.Color.background
    font.family: "monospace"; font.pixelSize: 12
    leftPadding: 10; rightPadding: 10
    verticalAlignment: TextInput.AlignVCenter
    background: Rectangle {
        radius: 3
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.05)
        border.color: root.activeFocus ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.25)
    }
}
