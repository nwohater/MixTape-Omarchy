import QtQuick
import QtQuick.Controls
import qs.Commons

TextField {
    id: root
    implicitHeight: 32
    color: Color.foreground
    placeholderTextColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
    selectionColor: Color.accent
    selectedTextColor: Color.background
    font.family: "monospace"; font.pixelSize: 12
    leftPadding: 10; rightPadding: 10
    verticalAlignment: TextInput.AlignVCenter
    background: Rectangle {
        radius: 3
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.25)
    }
}
