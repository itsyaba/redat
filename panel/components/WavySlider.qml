import QtQuick
import Caelestia.Config
import qs.services

// Caelestia-style slider: the filled part is a wave (moving while `animate`), the rest a flat
// track, with a pill handle. Reports the new value on release.
Item {
    id: root

    property real value: 0.5 // 0..1
    property bool animate: false
    property real phase: 0
    readonly property real shown: dragging ? dragValue : value
    property bool dragging: false
    property real dragValue: 0
    signal moved(real value)

    implicitHeight: 28

    readonly property real handleX: 6 + shown * (width - 12)

    FrameAnimation {
        running: root.animate && root.visible
        onTriggered: {
            root.phase += frameTime * 3.2;
            wave.requestPaint();
        }
    }
    onShownChanged: wave.requestPaint()
    onWidthChanged: wave.requestPaint()

    Canvas {
        id: wave
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const mid = height / 2;
            const end = Math.max(0, root.handleX - 8);
            // filled wave
            ctx.strokeStyle = Theme.primary;
            ctx.lineWidth = 4;
            ctx.lineCap = "round";
            ctx.beginPath();
            for (let x = 2; x <= end; x += 1) {
                const y = mid + Math.sin(x / 40 * Math.PI * 2 - root.phase) * 3.2;
                if (x === 2)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            if (end > 2)
                ctx.stroke();
            // rest of the track
            ctx.strokeStyle = Theme.secondaryContainer;
            ctx.beginPath();
            ctx.moveTo(Math.min(width - 2, root.handleX + 8), mid);
            ctx.lineTo(width - 2, mid);
            if (root.handleX + 8 < width - 2)
                ctx.stroke();
        }
    }

    Rectangle {
        x: root.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: area.pressed ? 22 : 18
        radius: 2
        color: Theme.primary
        Behavior on height { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function at(x) {
            return Math.max(0, Math.min(1, (x - 6) / (root.width - 12)));
        }
        onPressed: e => {
            root.dragValue = at(e.x);
            root.dragging = true;
        }
        onPositionChanged: e => root.dragValue = at(e.x)
        onReleased: {
            root.dragging = false;
            root.moved(root.dragValue);
        }
    }
}
