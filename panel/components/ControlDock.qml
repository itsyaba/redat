import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

// Floating toolbar: wake word, reply speed (a chip that unfolds into the wavy slider), stop,
// the big morphing listen / pause / resume button, and a new conversation.
Rectangle {
    id: root

    property bool speedOpen: false
    readonly property bool talking: Redat.state === "speaking" || Redat.state === "thinking" || Redat.paused
    readonly property real shownSpeed: slider.dragging ? 0.5 + slider.dragValue * 1.5 : Redat.speed

    implicitHeight: 60
    implicitWidth: row.implicitWidth + 12
    radius: height / 2
    color: Qt.alpha(Theme.surfaceHigh, 0.92)
    border.width: 1
    border.color: Qt.alpha(Theme.outlineVariant, 0.5)

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 6
        spacing: 4

        TonalButton {
            flat: true
            icon: Redat.muted ? "notifications_off" : "notifications_active"
            tip: Redat.muted ? "«ረዳት» is off — click to turn on" : "Wake word «ረዳት» on"
            checked: Redat.muted
            fillColour: Theme.errorContainer
            fillText: Theme.error
            enabled: Redat.online
            implicitWidth: 44
            implicitHeight: 44
            iconSize: 22
            onClicked: Redat.send("mute")
        }

        // Speed chip + slider
        Rectangle {
            implicitHeight: 44
            implicitWidth: speedRow.implicitWidth + 24
            radius: 22
            color: root.speedOpen ? Theme.secondaryContainer : "transparent"
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on implicitWidth { NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.anim.expressiveDefaultSpatial.bezierCurve } }

            RowLayout {
                id: speedRow
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                spacing: 8

                Item {
                    implicitWidth: speedLabel.implicitWidth + 26
                    implicitHeight: 44
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Icon {
                            text: "speed"
                            size: 20
                            color: root.speedOpen ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                        }
                        Text {
                            id: speedLabel
                            text: root.shownSpeed.toFixed(2) + "×"
                            color: root.speedOpen ? Theme.fgSecondaryContainer : Theme.fgSurface
                            font.family: Theme.sans
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: Redat.online
                        onClicked: root.speedOpen = !root.speedOpen
                        // Scroll to nudge by 0.05×.
                        onWheel: wheel => {
                            const s = Math.max(0.5, Math.min(2, Math.round((Redat.speed + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)) * 20) / 20));
                            Redat.send("speed", String(s));
                        }
                    }
                }
                WavySlider {
                    id: slider
                    Layout.preferredWidth: root.speedOpen ? 170 : 0
                    Layout.rightMargin: root.speedOpen ? 6 : 0
                    visible: Layout.preferredWidth > 1
                    opacity: root.speedOpen ? 1 : 0
                    value: (Redat.speed - 0.5) / 1.5
                    animate: Redat.state === "speaking" && !Redat.paused
                    enabled: Redat.online
                    onMoved: v => Redat.send("speed", String(Math.round((0.5 + v * 1.5) * 20) / 20))
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.anim.expressiveDefaultSpatial.bezierCurve } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
        }

        TonalButton {
            flat: true
            icon: "stop"
            tip: "Stop"
            enabled: Redat.online && (Redat.state !== "idle" || Redat.paused)
            implicitWidth: 44
            implicitHeight: 44
            iconSize: 24
            onClicked: Redat.send("cancel")
        }

        TonalButton {
            filled: true
            implicitWidth: 72
            implicitHeight: 48
            iconSize: 28
            enabled: Redat.online
            fillColour: Redat.state === "listening" ? Theme.tertiaryContainer : Theme.primary
            fillText: Redat.state === "listening" ? Theme.fgTertiaryContainer : Theme.fgPrimary
            icon: root.talking ? (Redat.paused ? "play_arrow" : "pause") : Redat.state === "listening" ? "graphic_eq" : "mic"
            tip: root.talking ? (Redat.paused ? "Resume" : "Pause") : Redat.state === "listening" ? "Listening…" : "Listen (SUPER+Y)"
            onClicked: root.talking ? Redat.send("pause") : Redat.send("listen")
        }

        TonalButton {
            flat: true
            icon: "add_comment"
            tip: "New conversation"
            enabled: Redat.online
            implicitWidth: 44
            implicitHeight: 44
            iconSize: 22
            onClicked: Redat.send("reset")
        }
    }
}
