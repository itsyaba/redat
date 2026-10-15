pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import M3Shapes
import Caelestia.Services
import qs.services

// Redat's avatar in a Material "cookie" shape with a ring of bars around it, like the cover art
// in Caelestia's Media tab. The bars follow Redat's voice (cava on the audio output) while it
// speaks, my mic level while it listens, and drift slowly while it thinks.
Item {
    id: root

    property real coverSize: 196
    readonly property int count: 60
    readonly property string mode: !Redat.online ? "offline" : Redat.paused ? "paused" : Redat.state
    readonly property real centreX: width / 2
    readonly property real centreY: height / 2
    readonly property real spacing: 10
    readonly property real maxMagnitude: Math.min(width, height) / 2 - coverSize / 2 - spacing - 6
    readonly property real micLevel: {
        const l = Redat.levels;
        return l.length ? Math.min(1, Math.sqrt(l[l.length - 1]) / 42) : 0;
    }

    property var values: Array(count).fill(0.01)
    property real phase: 0

    CavaProvider {
        id: cava
        bars: root.count
    }
    // Only run cava around Redat's replies. It takes ~1s to warm up, so start it while thinking.
    ServiceRef {
        service: (root.mode === "speaking" || root.mode === "thinking") && root.visible ? cava : null
    }

    FrameAnimation {
        running: root.visible
        onTriggered: {
            const dt = frameTime;
            root.phase += dt;
            shape.rotation -= dt * ({ speaking: 16, thinking: 40, listening: 6 }[root.mode] ?? 0);
            const next = new Array(root.count);
            for (let i = 0; i < root.count; i++) {
                let target = 0.01;
                if (root.mode === "speaking")
                    target = cava.values[i] ?? 0.01;
                else if (root.mode === "listening")
                    target = root.micLevel * (0.3 + 0.7 * (0.5 + 0.5 * Math.sin(i * 0.7 + root.phase * 7)) * (0.5 + 0.5 * Math.sin(i * 0.23 - root.phase * 3.3)));
                else if (root.mode === "thinking")
                    target = 0.05 + 0.13 * (0.5 + 0.5 * Math.sin(i * Math.PI * 2 / root.count * 3 + root.phase * 4));
                next[i] = root.values[i] * 0.55 + Math.max(0.01, Math.min(1, target)) * 0.45;
            }
            root.values = next;
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        data: bars.instances
    }

    Variants {
        id: bars

        model: Array.from({ length: root.count }, (_, i) => i)

        ShapePath {
            id: bar

            required property int modelData
            readonly property real angle: modelData * 2 * Math.PI / root.count - Math.PI / 2
            readonly property real start: root.coverSize / 2 + root.spacing + strokeWidth / 2
            readonly property real dist: start + root.values[modelData] * root.maxMagnitude

            capStyle: ShapePath.RoundCap
            strokeWidth: 360 / root.count - 1
            strokeColor: Theme.primary
            fillColor: "transparent"
            startX: root.centreX + start * Math.cos(angle)
            startY: root.centreY + start * Math.sin(angle)

            PathLine {
                x: root.centreX + bar.dist * Math.cos(bar.angle)
                y: root.centreY + bar.dist * Math.sin(bar.angle)
            }
        }
    }

    // Avatar
    Item {
        id: cover

        anchors.centerIn: parent
        width: root.coverSize
        height: root.coverSize
        scale: root.mode === "listening" ? 1 + root.micLevel * 0.05 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }

        // Soft glow to lift it off the background (as Caelestia does).
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 1
            shadowColor: Theme.outline
            shadowOpacity: 0.3
        }

        Item {
            id: shapeWrapper
            anchors.fill: parent
            layer.enabled: true

            MaterialShape {
                id: shape
                implicitSize: cover.width
                animationDuration: 650
                color: root.mode === "offline" ? Theme.errorContainer : Theme.primaryContainer
                shape: ({
                        listening: MaterialShape.Cookie12Sided,
                        thinking: MaterialShape.SoftBurst,
                        speaking: MaterialShape.Cookie9Sided,
                        paused: MaterialShape.Circle,
                        offline: MaterialShape.Circle
                    })[root.mode] ?? MaterialShape.Cookie9Sided
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        // My own picture if there is one; otherwise the letter ረ.
        Image {
            id: photo
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.config/redat/avatar.png"
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.coverSize * 2, root.coverSize * 2)
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: shapeWrapper
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.coverSize * 0.03
            visible: photo.status !== Image.Ready
            text: "ረ"
            color: root.mode === "offline" ? Theme.onSurface : Theme.onPrimaryContainer
            font.family: "Noto Sans Ethiopic"
            font.pixelSize: root.coverSize * 0.44
            font.weight: Font.DemiBold
        }
    }
}
