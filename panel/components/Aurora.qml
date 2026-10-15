import QtQuick
import QtQuick.Effects
import qs.services

// Soft blurred light behind the avatar that drifts and swells with Redat's voice, tinted by state:
// a calm glow when idle, cool when listening, shifting while thinking, bright while speaking.
Item {
    id: root

    property string mode: "idle"
    property real energy: 0 // 0..1
    property real originX: 160
    property real originY: height / 2
    property real phase: 0

    readonly property color tint: ({
            listening: Qt.darker(Theme.tertiary, 1.9),
            thinking: Theme.secondaryContainer,
            speaking: Theme.primaryContainer,
            offline: Theme.errorContainer
        })[mode] ?? Theme.primaryContainer
    readonly property color accent: Qt.darker(Theme.tertiary, 2.1)
    // Deep tints only: pale ones blur into a grey haze over the dark panel.
    readonly property real strength: mode === "idle" || mode === "paused" ? 0.3 : 0.45 + energy * 0.5

    FrameAnimation {
        running: root.visible && root.mode !== "idle" && root.mode !== "paused" && root.mode !== "offline"
        onTriggered: root.phase += frameTime * (root.mode === "thinking" ? 0.9 : 0.45)
    }

    Item {
        id: lights
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Repeater {
            model: [
                { r: 170, dx: 0, dy: 0, s: 1.0, c: 0, sp: 1.0 },
                { r: 120, dx: 150, dy: -60, s: 0.7, c: 1, sp: 1.3 },
                { r: 140, dx: 90, dy: 90, s: 0.6, c: 2, sp: 0.8 },
                { r: 90, dx: 300, dy: 20, s: 0.35, c: 1, sp: 1.6 }
            ]

            Rectangle {
                required property var modelData
                readonly property real grow: 1 + root.energy * 0.35 * modelData.s

                width: modelData.r * 2 * grow
                height: width
                radius: width / 2
                x: root.originX + modelData.dx + Math.sin(root.phase * modelData.sp + modelData.c * 2.1) * 40 - width / 2
                y: root.originY + modelData.dy + Math.cos(root.phase * modelData.sp * 0.8 + modelData.c) * 28 - height / 2
                color: modelData.c === 0 ? root.tint : modelData.c === 1 ? root.accent : Theme.primaryContainer
                opacity: root.strength * modelData.s
                Behavior on color { ColorAnimation { duration: 600 } }
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: lights
        blurEnabled: true
        blur: 1
        blurMax: 64
        autoPaddingEnabled: false
    }
}
