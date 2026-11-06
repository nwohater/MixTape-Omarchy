import QtQuick
import QtQuick.Controls
import qs.Commons

Slider {
    id: root
    implicitHeight: 24
    background: Rectangle {
        x: root.leftPadding; y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth; height: 4
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
        Rectangle { width: root.visualPosition * parent.width; height: parent.height; color: Color.accent }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 12; height: 16; radius: 2
        color: root.pressed ? Color.accent : Color.foreground
        border.color: Color.accent
    }
}
