import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

// A command Claude ran, as an assist chip: icon, the command, how long it took. Spins while running.
Rectangle {
    id: root

    required property string name
    required property string input
    required property bool error
    required property real ms
    required property bool running
    property bool open: false
    signal clicked

    implicitHeight: 30
    implicitWidth: Math.min(row.implicitWidth + 20, 340)
    radius: 9
    color: open ? Theme.secondaryContainer : Qt.alpha(Theme.surfaceHighest, 0.85)
    border.width: running ? 1.5 : 1
    border.color: running ? Theme.primary : error ? Qt.alpha(Theme.error, 0.6) : Qt.alpha(Theme.outlineVariant, 0.9)
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 11
        spacing: 6

        Icon {
            text: root.running ? "progress_activity" : root.error ? "error" : root.name === "Bash" ? "terminal" : root.name === "WebSearch" ? "travel_explore" : root.name === "WebFetch" ? "language" : "build"
            size: 16
            color: root.error ? Theme.error : Theme.primary
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.running
            }
            onTextChanged: if (!root.running) rotation = 0
        }
        Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 250
            text: root.input
            elide: Text.ElideRight
            color: Theme.fgSurface
            font.family: Theme.mono
            font.pixelSize: 12
        }
        Text {
            visible: !root.running
            text: root.ms >= 1000 ? (root.ms / 1000).toFixed(1) + "s" : Math.round(root.ms) + "ms"
            color: Theme.fgSurfaceVariant
            font.family: Theme.sans
            font.pixelSize: 11
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.running
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
