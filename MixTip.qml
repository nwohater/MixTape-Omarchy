import QtQuick
import QtQuick.Controls
import qs.Commons

ToolTip {
    id: root
    delay: 500
    contentItem: Text {
        text: root.text
        color: Color.foreground
        font.family: "monospace"; font.pixelSize: 11
    }
    background: Rectangle {
        color: Color.background
        border.color: Color.accent
        radius: 3
    }
}
