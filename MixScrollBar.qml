import QtQuick
import QtQuick.Controls
import qs.Commons

ScrollBar {
    id: root
    contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: Color.foreground
        opacity: root.pressed ? 0.6 : root.active ? 0.35 : 0
    }
    background: Item {}
}
