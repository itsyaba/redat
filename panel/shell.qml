//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

// ረዳት panel: drops down from the top while Redat is active. Shows what it heard, the commands
// it runs and its reply as it streams, with controls and a text box. Run: qs -p ~/projects/redat/panel
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

ShellRoot {
    id: shell

    property bool open: false // window mapped
    property bool slid: false // card slid down (animated)
    property bool pinned: false
    property bool typing: false // opened from the shortcut: grab the keyboard for the text box
    property bool speakReplies: true
    property ShellScreen target: Quickshell.screens[0] // the focused monitor when it opened

    function show(focus) {
        if (!open)
            target = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        open = true;
        slideIn.restart(); // after the window maps, so the slide-down animates
        if (focus)
            typing = true;
        hideTimer.stop();
    }
    function hide() {
        slid = false;
        typing = false;
        closing.restart();
    }

    Timer {
        id: slideIn
        interval: 16
        onTriggered: shell.slid = true
    }

    Connections {
        target: Redat
        function onActivity() {
            shell.show(false);
        }
    }

    // Close a while after Redat goes idle, unless pinned, hovered or being typed in.
    Timer {
        id: hideTimer
        interval: 9000
        running: shell.slid && !shell.pinned && !shell.typing && Redat.state === "idle" && !Redat.paused && !win.hovered
        onTriggered: shell.hide()
    }

    // Unmap once the slide-up animation has finished.
    Timer {
        id: closing
        interval: 340
        onTriggered: if (!shell.slid) shell.open = false
    }

    IpcHandler {
        target: "panel"
        function toggle(): void {
            if (shell.slid)
                shell.hide();
            else
                shell.show(true);
        }
        function open(): void {
            shell.show(true);
        }
        function close(): void {
            shell.hide();
        }
    }

    PanelWindow {
        id: win

        property bool hovered: hover.hovered

        visible: shell.open
        screen: shell.target
        anchors.top: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "redat-panel"
        WlrLayershell.keyboardFocus: shell.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        color: "transparent"
        implicitWidth: 760
        implicitHeight: card.implicitHeight + 24

        Rectangle {
            id: card

            width: parent.width - 24
            x: 12
            y: shell.slid ? 10 : -height - 20
            implicitHeight: body.implicitHeight + 28
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.6)
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            HoverHandler { id: hover }

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12

                // ── Header: orb, state, pin/close
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Orb {}

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "ረዳት"
                            color: Theme.onSurface
                            font.family: Theme.font
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: !Redat.online ? "አልተገናኘም · daemon offline (redat start)"
                                : Redat.paused ? "ቆሟል · paused"
                                : Redat.state === "listening" ? (Redat.followUp ? "ይቀጥሉ… · follow-up" : "እያዳመጥኩ ነው… · listening")
                                : Redat.state === "thinking" ? "እያሰብኩ ነው… · thinking"
                                : Redat.state === "speaking" ? "እየተናገርኩ ነው… · speaking"
                                : "ዝግጁ · ready"
                            color: !Redat.online ? Theme.error : Theme.onSurfaceVariant
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }

                    Wave {
                        visible: Redat.state === "listening"
                        Layout.leftMargin: 8
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: Redat.muted
                        implicitWidth: muteLabel.implicitWidth + 20
                        implicitHeight: 26
                        radius: 13
                        color: Theme.surfaceHighest
                        Text {
                            id: muteLabel
                            anchors.centerIn: parent
                            text: "🔕 wake word off"
                            color: Theme.onSurfaceVariant
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    IconButton {
                        icon: "keep"
                        tip: shell.pinned ? "Unpin" : "Keep open"
                        active: shell.pinned
                        onClicked: shell.pinned = !shell.pinned
                    }
                    IconButton {
                        icon: "close"
                        tip: "Close (Esc)"
                        onClicked: shell.hide()
                    }
                }

                // ── Conversation
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(Math.max(list.contentHeight, 0), 460)
                    visible: Redat.turns.count > 0
                    color: "transparent"
                    clip: true

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: Redat.turns
                        spacing: 18
                        boundsBehavior: Flickable.StopAtBounds
                        // Stick to the newest message while it streams, unless I've scrolled up.
                        property bool follow: true
                        onMovementEnded: follow = atYEnd
                        onContentHeightChanged: if (follow) Qt.callLater(positionViewAtEnd)
                        onCountChanged: {
                            follow = true;
                            Qt.callLater(positionViewAtEnd);
                        }
                        delegate: TurnView {
                            width: ListView.view.width
                        }
                    }
                }

                Text {
                    visible: Redat.turns.count === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    text: "«ረዳት» ይበሉ፣ SUPER+Y ይጫኑ፣ ወይም ከታች ይጻፉ\nSay “ረዳት”, press SUPER+Y, or type below"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.font
                    font.pixelSize: 13
                    lineHeight: 1.2
                }

                Text {
                    visible: Redat.lastError !== ""
                    Layout.fillWidth: true
                    text: "⚠ " + Redat.lastError
                    color: Theme.error
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                // ── Text box
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: 26
                    color: Theme.surfaceHigh
                    border.width: input.activeFocus ? 2 : 0
                    border.color: Theme.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 6
                        spacing: 6

                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            color: Theme.onSurface
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.onPrimary
                            font.family: Theme.font
                            font.pixelSize: 15
                            clip: true
                            focus: true
                            activeFocusOnPress: true

                            function submit() {
                                const t = text.trim();
                                if (!t)
                                    return;
                                Redat.send("say", t, { silent: !shell.speakReplies });
                                text = "";
                                shell.typing = false;
                            }

                            onAccepted: submit()
                            Keys.onEscapePressed: shell.hide()
                            onActiveFocusChanged: if (activeFocus) hideTimer.stop()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !input.text && !input.preeditText
                                text: "ይጻፉ… · type a message"
                                color: Theme.onSurfaceVariant
                                font: input.font
                                opacity: 0.7
                            }
                        }

                        IconButton {
                            icon: shell.speakReplies ? "volume_up" : "volume_off"
                            tip: shell.speakReplies ? "Typed turns: spoken reply" : "Typed turns: silent reply"
                            onClicked: shell.speakReplies = !shell.speakReplies
                        }
                        IconButton {
                            icon: "arrow_upward"
                            active: input.text.trim() !== ""
                            enabled: Redat.online && input.text.trim() !== ""
                            tip: "Send (Enter)"
                            onClicked: input.submit()
                        }
                    }
                }

                // ── Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        big: true
                        icon: "mic"
                        tip: Redat.state === "listening" ? "Stop recording" : "Listen (SUPER+Y)"
                        active: Redat.state === "listening"
                        enabled: Redat.online
                        onClicked: Redat.send("listen")
                    }
                    IconButton {
                        big: true
                        icon: Redat.paused ? "play_arrow" : "pause"
                        tip: Redat.paused ? "Resume" : "Pause"
                        active: Redat.paused
                        activeColour: Theme.tertiary
                        enabled: Redat.online && (Redat.state === "speaking" || Redat.state === "thinking" || Redat.paused)
                        onClicked: Redat.send("pause")
                    }
                    IconButton {
                        big: true
                        icon: "stop"
                        tip: "Stop"
                        enabled: Redat.online && Redat.state !== "idle"
                        onClicked: Redat.send("cancel")
                    }

                    Item { Layout.fillWidth: true }

                    // Reply speed
                    Rectangle {
                        implicitHeight: 40
                        implicitWidth: speedRow.implicitWidth + 8
                        radius: 20
                        color: Theme.surfaceHigh
                        RowLayout {
                            id: speedRow
                            anchors.centerIn: parent
                            spacing: 0
                            IconButton {
                                icon: "remove"
                                tip: "Slower"
                                enabled: Redat.online && Redat.speed > 0.55
                                onClicked: Redat.send("speed", String(Math.round((Redat.speed - 0.05) * 100) / 100))
                            }
                            Item {
                                Layout.minimumWidth: 66
                                implicitWidth: speedLabel.implicitWidth
                                implicitHeight: 40
                                Row {
                                    id: speedLabel
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "speed"
                                        size: 18
                                        color: Theme.onSurfaceVariant
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Redat.speed.toFixed(2) + "×"
                                        color: Theme.onSurface
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                    }
                                }
                                ToolTipLite {
                                    text: "Reply speed (click: reset to 1.15×)"
                                    shown: speedArea.containsMouse
                                }
                                MouseArea {
                                    id: speedArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Redat.send("speed", "1.15")
                                }
                            }
                            IconButton {
                                icon: "add"
                                tip: "Faster"
                                enabled: Redat.online && Redat.speed < 1.95
                                onClicked: Redat.send("speed", String(Math.round((Redat.speed + 0.05) * 100) / 100))
                            }
                        }
                    }

                    IconButton {
                        icon: Redat.muted ? "notifications_off" : "notifications_active"
                        tip: Redat.muted ? "Wake word off — turn on" : "Wake word on — turn off"
                        active: Redat.muted
                        activeColour: Theme.errorContainer
                        activeText: Theme.onSurface
                        enabled: Redat.online
                        onClicked: Redat.send("mute")
                    }
                    IconButton {
                        icon: "restart_alt"
                        tip: "New conversation"
                        enabled: Redat.online
                        onClicked: Redat.send("reset")
                    }
                }
            }
        }
    }
}
