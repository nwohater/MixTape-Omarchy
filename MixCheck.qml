import QtQuick
import QtQuick.Controls
import qs.Commons

CheckBox {
    id: root
    indicator: Rectangle {
        x: (root.width - width) / 2; y: (root.height - height) / 2
        width: 16; height: 16; radius: 2
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeFocus || root.checked ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 1; color: Color.accent; visible: root.checked }
    }
}
