pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

// One exchange in the lyrics-style chat: what I said, the commands it ran (click for output),
// and the reply. Older exchanges fade back like past lyric lines.
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

    spacing: 6
    opacity: current ? 1 : 0.42
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // Me
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Icon {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 1
            text: root.source === "voice" ? "mic" : "keyboard"
            size: 16
            color: Theme.secondary
        }
        Text {
            Layout.fillWidth: true
            text: root.heard || "…"
            wrapMode: Text.Wrap
            color: Theme.secondary
            font: Tokens.font.title.small
        }
    }

    // Commands
    Repeater {
        model: root.tools

        ColumnLayout {
            id: tool

            required property string name
            required property string input
            required property string output
            required property bool error
            required property real ms
            required property bool running
            property bool open: false

            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Icon {
                    text: tool.running ? "progress_activity" : tool.error ? "error" : tool.name === "Bash" ? "terminal" : tool.name === "WebSearch" ? "travel_explore" : "language"
                    size: 15
                    color: tool.error ? Theme.error : Theme.tertiary
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: tool.running
                    }
                    onTextChanged: if (!tool.running) rotation = 0
                }
                Text {
                    Layout.fillWidth: true
                    text: tool.input
                    elide: Text.ElideRight
                    color: Theme.onSurfaceVariant
                    font.family: "CaskaydiaCove Nerd Font"
                    font.pixelSize: 12
                }
                Text {
                    visible: !tool.running
                    text: tool.ms >= 1000 ? (tool.ms / 1000).toFixed(1) + "s" : Math.round(tool.ms) + "ms"
                    color: Theme.outline
                    font: Tokens.font.label.small
                }
            }
            Rectangle {
                Layout.fillWidth: true
                visible: tool.open
                implicitHeight: Math.min(out.implicitHeight + 12, 140)
                radius: 10
                color: Qt.alpha(Theme.surfaceHighest, 0.7)
                clip: true
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentHeight: out.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    Text {
                        id: out
                        width: parent.width
                        text: tool.output.trim() || "(no output)"
                        wrapMode: Text.WrapAnywhere
                        color: tool.error ? Theme.error : Theme.onSurfaceVariant
                        font.family: "CaskaydiaCove Nerd Font"
                        font.pixelSize: 11
                    }
                }
            }
            TapHandler {
                enabled: !tool.running
                onTapped: tool.open = !tool.open
            }
        }
    }

    // Reply
    Text {
        Layout.fillWidth: true
        visible: root.am !== "" || !root.done
        text: root.am || "…"
        wrapMode: Text.Wrap
        color: Theme.onSurface
        font: Tokens.font.body.large
        lineHeight: 1.12
    }
    Text {
        Layout.fillWidth: true
        visible: root.en !== ""
        text: root.en
        wrapMode: Text.Wrap
        color: Theme.onSurfaceVariant
        font: Tokens.font.body.small
    }
    Text {
        Layout.fillWidth: true
        visible: root.error !== ""
        text: "⚠ " + root.error
        wrapMode: Text.Wrap
        color: Theme.error
        font: Tokens.font.body.small
    }
}
