import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

ToolTip {
    id: root
    delay: 500
    contentItem: Text {
        text: root.text
        color: Commons.Color.foreground
        font.family: "monospace"; font.pixelSize: 11
    }
    background: Rectangle {
        color: Commons.Color.background
        border.color: Commons.Color.accent
        radius: 3
    }
}
