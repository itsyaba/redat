import QtQuick
import QtQuick.Layouts
import qs.services

// One command Claude ran: click to see its output.
Rectangle {
    id: root

    required property string name
    required property string input
    required property string output
    required property bool error
    required property real ms
    required property bool running
    property bool open: false

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 16
    radius: 14
    color: Theme.surfaceHigh
    border.width: 1
    border.color: error ? Qt.alpha(Theme.error, 0.5) : "transparent"

    // Below the content, so the output's Flickable still gets scroll/drag events.
    MouseArea {
        anchors.fill: parent
        enabled: !root.running
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 8
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                text: root.name === "Bash" ? "terminal" : root.name === "WebSearch" ? "travel_explore" : root.name === "WebFetch" ? "language" : "build"
                size: 18
                color: Theme.tertiary
            }
            Text {
                Layout.fillWidth: true
                text: root.input
                elide: Text.ElideRight
                maximumLineCount: 1
                color: Theme.onSurface
                font.family: Theme.mono
                font.pixelSize: 13
            }
            Text {
                visible: !root.running
                text: root.ms >= 1000 ? (root.ms / 1000).toFixed(1) + "s" : Math.round(root.ms) + "ms"
                color: Theme.onSurfaceVariant
                font.family: Theme.font
                font.pixelSize: 11
            }
            Icon {
                text: root.running ? "progress_activity" : root.error ? "error" : "check_circle"
                size: 18
                filled: !root.running
                color: root.running ? Theme.tertiary : root.error ? Theme.error : Theme.primary
                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.running
                }
            }
            Icon {
                visible: !root.running
                text: root.open ? "expand_less" : "expand_more"
                size: 18
                color: Theme.onSurfaceVariant
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.open
            implicitHeight: Math.min(out.implicitHeight + 16, 220)
            radius: 10
            color: Theme.surface
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentHeight: out.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: out
                    width: parent.width
                    text: root.output.trim() || "(no output)"
                    wrapMode: Text.WrapAnywhere
                    color: root.error ? Theme.error : Theme.onSurfaceVariant
                    font.family: Theme.mono
                    font.pixelSize: 12
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
