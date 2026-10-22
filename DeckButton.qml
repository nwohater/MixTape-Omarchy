import QtQuick
import QtQuick.Controls
import qs.Commons
// The built-in `Color` value type shadows the qs.Commons `Color` singleton
// in this context, so unqualified `Color.x` is silently undefined.
// Qualify through the module alias — see the long note in Widget.qml.
import qs.Commons as Commons

AbstractButton {
    id: root
    property string caption: ""
    property string hint: caption
    property color ink: Commons.Color.foreground
    property bool didHold: false
    property int transportDirection: 0
    signal held()
    implicitWidth: 72
    implicitHeight: 56
    hoverEnabled: true
    Accessible.name: hint
    onPressed: didHold = false
    onPressAndHold: { didHold = true; held() }
    background: Rectangle {
        radius: 3
        color: root.down ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.20)
                         : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.hovered ? 0.12 : 0.05)
        border.color: root.activeFocus ? Commons.Color.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
        opacity: root.enabled ? 1 : 0.35
        Rectangle { x: 5; y: parent.height - 5; width: parent.width - 10; height: 2; color: root.ink; opacity: 0.16 }
    }
    contentItem: Column {
        spacing: 3
        topPadding: 7
        Item {
            width: parent.width
            height: 23
            Text {
                anchors.centerIn: parent
                visible: root.transportDirection === 0
                text: root.text; color: root.ink; font.pixelSize: 19
            }
            Canvas {
                id: transportIcon
                anchors.centerIn: parent
                width: 28; height: 18
                visible: root.transportDirection !== 0
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = root.ink
                    for (var i = 0; i < 2; i++) {
                        var x = i * 14
                        ctx.beginPath()
                        ctx.moveTo(x + (root.transportDirection < 0 ? 12 : 0), 1)
                        ctx.lineTo(x + (root.transportDirection < 0 ? 0 : 12), 9)
                        ctx.lineTo(x + (root.transportDirection < 0 ? 12 : 0), 17)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
                Connections {
                    target: root
                    function onInkChanged() { transportIcon.requestPaint() }
                    function onTransportDirectionChanged() { transportIcon.requestPaint() }
                }
            }
        }
        Text { width: parent.width; text: root.caption; color: root.ink; opacity: 0.65; font.family: "monospace"; font.pixelSize: 9; horizontalAlignment: Text.AlignHCenter }
    }
    ToolTip.visible: hovered
    ToolTip.delay: 700
    ToolTip.text: hint
}
