import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

Slider {
    id: root
    implicitHeight: 24
    background: Rectangle {
        x: root.leftPadding; y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth; height: 4
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.15)
        Rectangle { width: root.visualPosition * parent.width; height: parent.height; color: Commons.Color.accent }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 12; height: 16; radius: 2
        color: root.pressed ? Commons.Color.accent : Commons.Color.foreground
        border.color: Commons.Color.accent
    }
}
