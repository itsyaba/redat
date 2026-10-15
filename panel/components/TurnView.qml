import QtQuick
import QtQuick.Layouts
import qs.services

// One exchange: what I said (or typed), the commands it ran, and the reply as it streams in.
ColumnLayout {
    id: root

    required property int id
    required property string source
    required property string heard
    required property string text
    required property bool done
    required property string error
    required property var tools
    property bool last: false

    readonly property var parts: text.split(/\n\s*EN:\s*/)
    readonly property string am: parts[0].trim()
    readonly property string en: parts.length > 1 ? parts[1].trim() : ""

    spacing: 8

    // Me
    Rectangle {
        Layout.alignment: Qt.AlignRight
        Layout.maximumWidth: root.width * 0.82
        implicitWidth: meRow.implicitWidth + 28
        implicitHeight: meRow.implicitHeight + 18
        radius: 20
        color: Theme.primaryContainer

        RowLayout {
            id: meRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.Layout.maximumWidth - 28)
            spacing: 8
            Icon {
                text: root.source === "voice" ? "mic" : "keyboard"
                size: 16
                color: Theme.onPrimaryContainer
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
            }
            Text {
                Layout.fillWidth: true
                text: root.heard || "…"
                wrapMode: Text.Wrap
                color: Theme.onPrimaryContainer
                font.family: Theme.font
                font.pixelSize: 15
            }
        }
    }

    // What it did
    Repeater {
        model: root.tools
        ToolRow {}
    }

    // Reply
    ColumnLayout {
        Layout.fillWidth: true
        Layout.rightMargin: 40
        spacing: 4
        visible: root.am !== "" || !root.done || root.error !== ""

        Text {
            Layout.fillWidth: true
            visible: root.am !== "" || !root.done
            text: root.am + (!root.done ? " ▍" : "")
            wrapMode: Text.Wrap
            color: Theme.onSurface
            font.family: Theme.font
            font.pixelSize: 17
            lineHeight: 1.15
            opacity: root.am === "" ? 0.5 : 1
        }
        Text {
            Layout.fillWidth: true
            visible: root.en !== ""
            text: root.en
            wrapMode: Text.Wrap
            color: Theme.onSurfaceVariant
            font.family: Theme.font
            font.pixelSize: 13
            font.italic: true
        }
        Text {
            Layout.fillWidth: true
            visible: root.error !== ""
            text: "⚠ " + root.error
            wrapMode: Text.Wrap
            color: Theme.error
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
