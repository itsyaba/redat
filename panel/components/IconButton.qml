import QtQuick
import qs.services

// Round icon button with a hover/press layer; `active` uses the filled, tinted look.
Rectangle {
    id: root

    property string icon
    property string tip
    property bool active: false
    property bool big: false
    property color activeColour: Theme.primary
    property color activeText: Theme.onPrimary
    signal clicked

    implicitWidth: big ? 52 : 40
    implicitHeight: implicitWidth
    radius: big ? 18 : 20
    color: active ? activeColour : (big ? Theme.secondaryContainer : "transparent")
    opacity: enabled ? 1 : 0.38

    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on radius { NumberAnimation { duration: 180 } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? root.activeText : Theme.onSurface
        opacity: area.pressed ? 0.16 : area.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.big ? 26 : 22
        filled: root.active
        color: root.active ? root.activeText : (root.big ? Theme.onSecondaryContainer : Theme.onSurfaceVariant)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressed: if (root.big) root.radius = 14
        onReleased: if (root.big) root.radius = 18
    }

    ToolTipLite {
        text: root.tip
        shown: area.containsMouse && root.tip !== ""
    }
}
