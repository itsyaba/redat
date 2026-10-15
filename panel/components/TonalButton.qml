import QtQuick
import Caelestia.Config
import qs.services

// Material 3 icon button (tonal or filled) whose corners morph tighter while pressed, like
// Caelestia's media controls.
Rectangle {
    id: root

    property string icon
    property string tip
    property bool filled: false // primary filled (the big play/pause button)
    property bool checked: false
    property real iconSize: 24
    property color fillColour: Theme.primary
    property color onFillColour: Theme.onPrimary
    signal clicked

    readonly property bool lit: filled || checked
    implicitWidth: 48
    implicitHeight: 48
    radius: area.pressed ? Math.min(height / 2, 12) : (checked && !filled ? 16 : height / 2)
    color: lit ? fillColour : Theme.secondaryContainer
    opacity: enabled ? 1 : 0.38

    Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.anim.expressiveFastSpatial.bezierCurve } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.lit ? root.onFillColour : Theme.onSecondaryContainer
        opacity: area.pressed ? 0.14 : area.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.iconSize
        filled: root.lit
        color: root.lit ? root.onFillColour : Theme.onSecondaryContainer
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ToolTipLite {
        text: root.tip
        shown: area.containsMouse && root.tip !== ""
    }
}
