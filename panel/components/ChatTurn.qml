pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

// One exchange: what I said (a bubble on the right), the commands Claude ran (chips, click for
// output) and Redat's reply in large Amharic with a caret while it streams. The latest exchange
// is the big one; earlier ones shrink back but stay readable.
ColumnLayout {
    id: root

    required property int index
    required property int id
    required property string source
    required property string heard
    required property string text
    required property bool done
    required property string error
    required property var tools
    property bool current: false

    readonly property var parts: text.split(/\n\s*EN:\s*/)
    readonly property string am: parts[0].trim()
    readonly property string en: parts.length > 1 ? parts[1].trim() : ""
    readonly property bool streaming: !done && am !== ""
    property int openTool: -1

    spacing: current ? 10 : 6
    opacity: current ? 1 : 0.72
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // Me
    Rectangle {
        Layout.alignment: Qt.AlignRight
        Layout.maximumWidth: root.width * 0.8
        implicitWidth: me.implicitWidth + 30
        implicitHeight: me.implicitHeight + 14
        radius: 16
        bottomRightRadius: 5
        color: Qt.alpha(Theme.secondaryContainer, root.current ? 0.95 : 0.7)

        RowLayout {
            id: me
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 30)
            spacing: 6
            Icon {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                text: root.source === "voice" ? "mic" : "keyboard"
                size: 15
                color: Theme.fgSecondaryContainer
                opacity: 0.8
            }
            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: root.width * 0.8 - 52
                text: root.heard || (root.done ? "…" : "እያዳመጥኩ…")
                wrapMode: Text.Wrap
                color: Theme.fgSecondaryContainer
                font.family: Theme.font
                font.pixelSize: root.current ? 16 : 14
                font.weight: Font.Medium
            }
        }
    }

    // Commands
    Flow {
        Layout.fillWidth: true
        visible: root.tools.count > 0
        spacing: 6

        Repeater {
            model: root.tools

            ToolChip {
                required property int index
                open: root.openTool === index
                onClicked: root.openTool = root.openTool === index ? -1 : index
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        visible: root.openTool >= 0 && root.openTool < root.tools.count
        implicitHeight: Math.min(out.implicitHeight + 16, 150)
        radius: 12
        color: Qt.alpha(Theme.surfaceHighest, 0.9)
        clip: true
        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: out.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            TextEdit {
                id: out
                readonly property var tool: root.openTool >= 0 && root.openTool < root.tools.count ? root.tools.get(root.openTool) : null
                width: parent.width
                readOnly: true
                selectByMouse: true
                text: tool ? (tool.output.trim() || "(no output)") : ""
                wrapMode: Text.WrapAnywhere
                color: tool && tool.error ? Theme.error : Theme.fgSurfaceVariant
                selectionColor: Theme.primary
                selectedTextColor: Theme.fgPrimary
                font.family: Theme.mono
                font.pixelSize: 12
            }
        }
    }

    // Reply (selectable, so I can copy it)
    TextEdit {
        id: reply
        Layout.fillWidth: true
        visible: root.am !== ""
        readOnly: true
        selectByMouse: true
        text: root.am || "…"
        wrapMode: Text.Wrap
        color: Theme.fgSurface
        selectionColor: Theme.primary
        selectedTextColor: Theme.fgPrimary
        font.family: Theme.font
        font.pixelSize: root.current ? 23 : 16
        font.weight: root.current ? Font.Medium : Font.Normal

        // Streaming caret at the end of the text.
        Rectangle {
            readonly property rect end: reply.positionToRectangle(reply.length)
            visible: root.streaming
            x: end.x + 4
            y: end.y + end.height * 0.18
            width: 4
            height: end.height * 0.68
            radius: 2
            color: Theme.primary
            SequentialAnimation on opacity {
                running: root.current && !root.done
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 450; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
            }
        }
    }
    // Thinking: three bouncing dots until the first words arrive.
    Row {
        visible: !root.done && root.am === "" && root.heard !== ""
        spacing: 7
        topPadding: 6
        bottomPadding: 6
        Repeater {
            model: 3
            Rectangle {
                id: dot
                required property int index
                width: 10
                height: 10
                radius: 5
                color: Theme.primary
                SequentialAnimation on y {
                    running: dot.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: dot.index * 140 }
                    NumberAnimation { from: 0; to: -7; duration: 260; easing.type: Easing.OutQuad }
                    NumberAnimation { from: -7; to: 0; duration: 260; easing.type: Easing.InQuad }
                    PauseAnimation { duration: (2 - dot.index) * 140 + 200 }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.en !== ""
        text: root.en
        wrapMode: Text.Wrap
        color: Theme.fgSurfaceVariant
        font.family: Theme.sans
        font.pixelSize: root.current ? 14 : 12
        font.italic: true
    }
    Text {
        Layout.fillWidth: true
        visible: root.error !== ""
        text: "⚠ " + root.error
        wrapMode: Text.Wrap
        color: Theme.error
        font.family: Theme.sans
        font.pixelSize: 13
    }
}
