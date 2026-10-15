import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

// What Redat is doing, as a tinted pill with a breathing dot: እያዳመጥኩ / እያሰብኩ / እየተናገርኩ …
Rectangle {
    id: root

    property string mode: "idle"
    property bool followUp: false

    readonly property var look: ({
            offline: { am: "አልተገናኘም", icon: "cloud_off", bg: Theme.errorContainer, fg: Theme.error },
            paused: { am: "ቆሟል", icon: "pause", bg: Theme.surfaceHighest, fg: Theme.fgSurfaceVariant },
            listening: { am: root.followUp ? "ይቀጥሉ…" : "እያዳመጥኩ ነው", icon: "mic", bg: Theme.tertiaryContainer, fg: Theme.fgTertiaryContainer },
            thinking: { am: "እያሰብኩ ነው", icon: "neurology", bg: Theme.secondaryContainer, fg: Theme.fgSecondaryContainer },
            speaking: { am: "እየተናገርኩ ነው", icon: "graphic_eq", bg: Theme.primaryContainer, fg: Theme.fgPrimaryContainer },
            idle: { am: "ዝግጁ", icon: "check_circle", bg: Theme.surfaceHigh, fg: Theme.fgSurfaceVariant }
        })[mode] ?? look.idle
    readonly property bool busy: mode === "listening" || mode === "thinking" || mode === "speaking"

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 24
    radius: height / 2
    color: look.bg
    Behavior on color { ColorAnimation { duration: 300 } }
    Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.anim.expressiveFastSpatial.bezierCurve } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Item {
            implicitWidth: 18
            implicitHeight: 18
            // Pulsing halo while busy.
            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: root.look.fg
                opacity: 0
                visible: root.busy
                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.35; to: 0; duration: 1100; easing.type: Easing.OutCubic }
                }
                SequentialAnimation on scale {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.5; to: 1.5; duration: 1100; easing.type: Easing.OutCubic }
                }
            }
            Icon {
                anchors.centerIn: parent
                text: root.look.icon
                size: 17
                filled: true
                color: root.look.fg
            }
        }
        Text {
            text: root.look.am
            color: root.look.fg
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
    }
}
