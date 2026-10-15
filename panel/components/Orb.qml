import QtQuick
import qs.services

// The state orb: breathes with the mic while listening, spins while thinking, pulses while speaking.
Item {
    id: root

    readonly property string mode: !Redat.online ? "offline" : Redat.paused ? "paused" : Redat.state
    readonly property real level: Redat.levels.length ? Redat.levels[Redat.levels.length - 1] : 0
    readonly property color tint: mode === "listening" ? Theme.primary
        : mode === "thinking" ? Theme.tertiary
        : mode === "speaking" ? Theme.primary
        : mode === "offline" ? Theme.error
        : Theme.outline

    implicitWidth: 52
    implicitHeight: 52

    // Soft halo
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: width / 2
        color: root.tint
        opacity: root.mode === "idle" || root.mode === "offline" ? 0 : 0.18
        scale: root.mode === "listening" ? 1 + Math.min(root.level / 1800, 0.45) : halo.s
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on opacity { NumberAnimation { duration: 250 } }

        QtObject {
            id: halo
            property real s: 1
        }
        SequentialAnimation {
            running: root.mode === "speaking"
            loops: Animation.Infinite
            onStopped: halo.s = 1
            NumberAnimation { target: halo; property: "s"; to: 1.28; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { target: halo; property: "s"; to: 1.02; duration: 520; easing.type: Easing.InOutSine }
        }
    }

    // Core
    Rectangle {
        id: core
        anchors.centerIn: parent
        width: 38
        height: 38
        radius: 19
        color: root.mode === "idle" || root.mode === "paused" ? Theme.surfaceHighest : root.tint
        Behavior on color { ColorAnimation { duration: 250 } }

        Icon {
            anchors.centerIn: parent
            filled: true
            size: 22
            color: root.mode === "idle" || root.mode === "paused" ? Theme.onSurfaceVariant : Theme.onPrimary
            text: ({ listening: "mic", thinking: "neurology", speaking: "graphic_eq", paused: "pause", offline: "cloud_off" })[root.mode] ?? "auto_awesome"
        }
    }

    // Orbiting dots while thinking
    Item {
        anchors.fill: parent
        visible: root.mode === "thinking"
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 1400
            loops: Animation.Infinite
            running: root.mode === "thinking"
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 6 - index
                height: width
                radius: width / 2
                color: Theme.tertiary
                opacity: 1 - index * 0.28
                x: root.width / 2 + Math.cos(-index * 0.45) * 24 - width / 2
                y: root.height / 2 + Math.sin(-index * 0.45) * 24 - height / 2
            }
        }
    }
}
