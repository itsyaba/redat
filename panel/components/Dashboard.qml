pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import qs.services

// Everything inside the panel: the avatar ring on the left with an aurora behind it that swells
// with Redat's voice, and on the right a header (name, state, model), the conversation as a stage
// where the latest reply is big, and a composer next to a floating control dock.
Item {
    id: root

    // The window-level state lives in shell.qml (pinned, typing, speakReplies, hide()).
    required property var host
    readonly property string mode: !Redat.online ? "offline" : Redat.paused ? "paused" : Redat.state

    function focusInput() {
        input.forceActiveFocus();
    }

    // Rounded clip for the background light.
    Rectangle {
        id: roundMask
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        visible: false
        layer.enabled: true
    }
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundMask
        }
        Aurora {
            anchors.fill: parent
            mode: root.mode
            energy: avatar.energy
            originX: avatar.x + avatar.width / 2 + 20
            originY: avatar.y + avatar.height / 2 + 20
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 22

        AvatarVisualiser {
            id: avatar
            Layout.fillHeight: true
            implicitWidth: 300
            coverSize: 196
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // ── Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "ረዳት"
                    color: Theme.fgSurface
                    font.family: Theme.font
                    font.pixelSize: 28
                    font.weight: Font.Bold
                }
                StatePill {
                    mode: root.mode
                    followUp: Redat.followUp
                }
                Text {
                    Layout.fillWidth: true
                    text: Redat.online ? `Claude ${Redat.model} · ${Redat.voice}` : "redat start"
                    color: Theme.outline
                    font.family: Theme.sans
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                TonalButton {
                    flat: true
                    icon: "keep"
                    tip: root.host.pinned ? "Unpin" : "Keep open"
                    checked: root.host.pinned
                    implicitWidth: 36
                    implicitHeight: 36
                    iconSize: 19
                    onClicked: root.host.pinned = !root.host.pinned
                }
                TonalButton {
                    flat: true
                    icon: "close"
                    tip: "Close (Esc)"
                    implicitWidth: 36
                    implicitHeight: 36
                    iconSize: 19
                    onClicked: root.host.hide()
                }
            }

            // ── Conversation stage
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: fade
                }
                Rectangle {
                    id: fade
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.14; color: "white" }
                        GradientStop { position: 1; color: "white" }
                    }
                }

                ListView {
                    id: chat
                    anchors.fill: parent
                    anchors.rightMargin: 4
                    model: Redat.turns
                    spacing: 18
                    topMargin: 24
                    bottomMargin: 6
                    boundsBehavior: Flickable.StopAtBounds
                    property bool follow: true
                    onMovementEnded: follow = atYEnd
                    onContentHeightChanged: if (follow) Qt.callLater(positionViewAtEnd)
                    onCountChanged: {
                        follow = true;
                        Qt.callLater(positionViewAtEnd);
                    }
                    delegate: ChatTurn {
                        width: ListView.view.width
                        current: index === ListView.view.count - 1
                    }
                }

                // Empty: a greeting for the time of day and a few things to try.
                ColumnLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    visible: Redat.turns.count === 0
                    spacing: 6

                    Text {
                        readonly property int hour: new Date().getHours()
                        text: hour < 12 ? "እንደምን አደሩ!" : hour < 18 ? "እንደምን ዋሉ!" : "እንደምን አመሹ!"
                        color: Theme.fgSurface
                        font.family: Theme.font
                        font.pixelSize: 30
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "ምን ልርዳዎት? «ረዳት» ይበሉ ወይም ከታች ይጻፉ።"
                        color: Theme.fgSurfaceVariant
                        font.family: Theme.font
                        font.pixelSize: 17
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        spacing: 8
                        Repeater {
                            model: [
                                { icon: "schedule", text: "ሰዓቱ ስንት ነው?" },
                                { icon: "partly_cloudy_day", text: "የዛሬ የአየር ሁኔታ" },
                                { icon: "memory", text: "ኮምፒውተሬ እንዴት ነው?" },
                                { icon: "sentiment_very_satisfied", text: "ቀልድ ንገረኝ" }
                            ]
                            Rectangle {
                                id: chip
                                required property var modelData
                                implicitHeight: 38
                                implicitWidth: chipRow.implicitWidth + 28
                                radius: 12
                                color: chipArea.containsMouse ? Theme.secondaryContainer : Qt.alpha(Theme.surfaceHigh, 0.85)
                                border.width: 1
                                border.color: Qt.alpha(Theme.outlineVariant, 0.8)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Icon {
                                        text: chip.modelData.icon
                                        size: 18
                                        color: Theme.primary
                                    }
                                    Text {
                                        text: chip.modelData.text
                                        color: Theme.fgSurface
                                        font.family: Theme.font
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                    }
                                }
                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: Redat.online
                                    onClicked: Redat.send("say", chip.modelData.text, { silent: !root.host.speakReplies })
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Redat.lastError !== ""
                text: "⚠ " + Redat.lastError
                color: Theme.error
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: 13
            }

            // ── Composer + dock
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 60
                    radius: 30
                    color: Qt.alpha(Theme.surfaceHigh, 0.92)
                    border.width: root.host.typing ? 2 : 1
                    border.color: root.host.typing ? Theme.primary : Qt.alpha(Theme.outlineVariant, 0.5)
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    TapHandler {
                        onTapped: root.host.typing = true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 8
                        spacing: 10

                        Icon {
                            text: "edit"
                            size: 20
                            color: root.host.typing ? Theme.primary : Theme.fgSurfaceVariant
                        }
                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            color: Theme.fgSurface
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.fgPrimary
                            font.family: Theme.font
                            font.pixelSize: 17
                            clip: true
                            focus: true

                            function submit() {
                                const t = text.trim();
                                if (!t)
                                    return;
                                Redat.send("say", t, { silent: !root.host.speakReplies });
                                text = "";
                                root.host.typing = false;
                            }

                            onAccepted: submit()
                            Keys.onEscapePressed: {
                                text = "";
                                root.host.hide();
                            }
                            TapHandler {
                                onTapped: root.host.typing = true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !input.text && !input.preeditText
                                text: "ለረዳት ይጻፉ…"
                                color: Theme.fgSurfaceVariant
                                opacity: 0.75
                                font: input.font
                            }
                        }
                        // Typed turns: spoken or silent reply.
                        TonalButton {
                            flat: true
                            icon: root.host.speakReplies ? "volume_up" : "volume_off"
                            tip: root.host.speakReplies ? "Typed messages: spoken reply" : "Typed messages: silent reply"
                            implicitWidth: 40
                            implicitHeight: 40
                            iconSize: 20
                            onClicked: root.host.speakReplies = !root.host.speakReplies
                        }
                        TonalButton {
                            filled: true
                            icon: "arrow_upward"
                            tip: "Send (Enter)"
                            visible: input.text.trim() !== ""
                            enabled: Redat.online
                            implicitWidth: 44
                            implicitHeight: 44
                            iconSize: 22
                            onClicked: input.submit()
                        }
                    }
                }

                ControlDock {}
            }
        }
    }
}
