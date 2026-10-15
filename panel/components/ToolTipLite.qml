import QtQuick
import qs.services

// Small tooltip under its parent, shown after a short hover.
Rectangle {
    id: root
    property string text
    property bool shown

    anchors.top: parent.bottom
    anchors.topMargin: 6
    anchors.horizontalCenter: parent.horizontalCenter
    z: 100
    width: label.implicitWidth + 16
    height: label.implicitHeight + 8
    radius: 8
    color: Theme.surfaceHighest
    visible: opacity > 0
    opacity: shown && delay.done ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Timer {
        id: delay
        property bool done: false
        interval: 500
        running: root.shown
        onTriggered: done = true
    }
    onShownChanged: if (!shown) delay.done = false

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.fgSurface
        font.family: Theme.font
        font.pixelSize: 12
    }
}
