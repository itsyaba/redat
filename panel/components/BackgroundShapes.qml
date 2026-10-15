pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import qs.services

// Faint Material shapes drifting behind the panel while Redat is busy (as in Caelestia's Media tab).
Item {
    id: root

    property bool running: false
    readonly property list<int> pool: [MaterialShape.Circle, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.SoftBurst, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Arch, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Fan, MaterialShape.Oval]
    readonly property int count: 14

    function rand(min, max) {
        return min + Math.random() * (max - min);
    }
    function signedRand(min, max) {
        return rand(min, max) * (Math.random() < 0.5 ? -1 : 1);
    }

    clip: true

    // Scatter once the panel has a size (it's 0×0 while the shapes are created).
    property bool placed: false
    onWidthChanged: {
        if (placed || width <= 0 || height <= 0)
            return;
        placed = true;
        for (let i = 0; i < shapes.count; i++) {
            const s = shapes.itemAt(i);
            s.x = rand(-s.width / 2, width - s.width / 2);
            s.y = rand(-s.height / 2, height - s.height / 2);
        }
    }

    Repeater {
        id: shapes
        model: root.count

        MaterialShape {
            required property int index
            property real vx: root.signedRand(4, 18)
            property real vy: root.signedRand(4, 18)
            property real vr: root.rand(-12, 12)
            readonly property int tint: Math.floor(Math.random() * 4)

            implicitSize: 36 + (index / root.count) * (124 - 36)
            shape: root.pool[Math.floor(Math.random() * root.pool.length)]
            color: [Theme.primaryContainer, Theme.secondaryContainer, Theme.tertiaryContainer, Theme.outlineVariant][tint]
            opacity: [0.16, 0.16, 0.04, 0.16][tint]
            rotation: root.rand(0, 360)
        }
    }

    FrameAnimation {
        running: root.running && root.visible && root.width > 0
        onTriggered: {
            const dt = frameTime;
            for (let i = 0; i < shapes.count; i++) {
                const s = shapes.itemAt(i);
                if (!s)
                    continue;
                s.x += s.vx * dt;
                s.y += s.vy * dt;
                s.rotation += s.vr * dt;
                if (s.x + s.width < 0)
                    s.x = root.width;
                else if (s.x > root.width)
                    s.x = -s.width;
                if (s.y + s.height < 0)
                    s.y = root.height;
                else if (s.y > root.height)
                    s.y = -s.height;
            }
        }
    }
}
