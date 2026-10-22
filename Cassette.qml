import QtQuick
import qs.Commons
// The built-in `Color` value type shadows the qs.Commons `Color` singleton
// in this context, so unqualified `Color.x` is silently undefined.
// Qualify through the module alias — see the long note in Widget.qml.
import qs.Commons as Commons

Rectangle {
    id: tape
    property bool playing: false
    property bool animationVisible: true
    property string title: "YOUR NEXT FAVORITE MIX"
    property color ink: Commons.Color.foreground
    color: Qt.rgba(ink.r, ink.g, ink.b, 0.035)
    border.color: ink
    border.width: 2
    radius: 12
    implicitWidth: 396
    implicitHeight: 210

    Repeater {
        model: 4
        Rectangle {
            required property int index
            width: 10; height: 10; radius: 5
            x: index % 2 === 0 ? 9 : tape.width - width - 9
            y: index < 2 ? 9 : tape.height - height - 9
            color: "transparent"
            border.color: tape.ink
            opacity: 0.5
            Rectangle { anchors.centerIn: parent; width: 6; height: 1; color: tape.ink }
            Rectangle { anchors.centerIn: parent; width: 1; height: 6; color: tape.ink }
        }
    }
    Rectangle {
        x: 26; y: 19; width: parent.width - 52; height: 46
        color: Commons.Color.accent
        Text {
            anchors.fill: parent; anchors.margins: 9
            text: "A / " + tape.title.toUpperCase()
            textFormat: Text.PlainText
            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
            color: Commons.Color.background; font.family: "monospace"; font.bold: true; font.pixelSize: 12
        }
    }
    Rectangle {
        x: 26; y: 78; width: parent.width - 52; height: 72
        radius: 36; color: Commons.Color.background; border.color: tape.ink
        Rectangle {
            anchors.centerIn: parent; width: parent.width - 98; height: 23
            color: "transparent"; border.color: tape.ink; opacity: 0.45
            Text { anchors.centerIn: parent; text: "≋≋≋≋≋≋≋≋≋"; color: tape.ink; font.family: "monospace" }
        }
        Repeater {
            model: 2
            Rectangle {
                id: reel
                objectName: "cassetteReel" + index
                required property int index
                x: index === 0 ? 9 : parent.width - width - 9
                anchors.verticalCenter: parent.verticalCenter
                width: 54; height: 54; radius: 27
                color: Commons.Color.background; border.color: tape.ink; border.width: 2
                Item {
                    anchors.centerIn: parent; width: 38; height: 38
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            anchors.centerIn: parent; width: 3; height: 38
                            color: tape.ink; rotation: index * 60
                        }
                    }
                    Rectangle { anchors.centerIn: parent; width: 13; height: 13; radius: 7; color: Commons.Color.background; border.color: tape.ink; border.width: 2 }
                }
                NumberAnimation on rotation {
                    from: 0; to: 360; duration: 2600; loops: Animation.Infinite
                    running: tape.playing && tape.animationVisible && tape.visible
                }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter; y: 160
        text: "TYPE II  /  HIGH BIAS  /  C—90"
        color: tape.ink; opacity: 0.55; font.family: "monospace"; font.pixelSize: 10
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
        width: parent.width * 0.6; height: 23; radius: 5
        color: "transparent"; border.color: tape.ink
        Text { anchors.centerIn: parent; text: "○     ▯     ▯     ○"; color: tape.ink; font.family: "monospace" }
    }
}
