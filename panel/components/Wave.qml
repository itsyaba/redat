import QtQuick
import qs.services

// Live mic level bars (newest on the right) while listening.
Row {
    id: root
    spacing: 3
    height: 28

    Repeater {
        model: 36
        Rectangle {
            required property int index
            readonly property var lv: Redat.levels
            readonly property real v: {
                const i = lv.length - 36 + index;
                return i >= 0 ? lv[i] : 0;
            }
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: Math.max(3, Math.min(root.height, 3 + Math.sqrt(v) * 0.7))
            radius: 1.5
            color: Theme.primary
            opacity: 0.35 + Math.min(v / 1500, 0.65)
            Behavior on height { NumberAnimation { duration: 80 } }
        }
    }
}
