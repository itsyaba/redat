//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

// ረዳት panel, laid out like Caelestia's Media tab: avatar + visualiser where the cover art is, AI
// info + controls where the track info is, and the chat where the lyrics are. It grows out of the
// top screen border with Caelestia's own blob renderer, so it joins the frame like the dashboard.
// Run: qs -p ~/projects/redat/panel (redat-panel.service)
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Caelestia.Blobs
import Caelestia.Config
import qs.services
import qs.components

ShellRoot {
    id: shell

    property bool open: false // window mapped
    property bool slid: false // panel out of the border (animated)
    property bool pinned: false
    property bool typing: false // grab the keyboard for the text box (shortcut, or clicked)
    onTypingChanged: if (typing) input.forceActiveFocus()
    property bool speakReplies: true
    property ShellScreen target: Quickshell.screens[0] // the focused monitor when it opened

    function show(focus) {
        if (focus)
            typing = true;
        if (open) {
            slid = true;
            return;
        }
        // Ask Hyprland which monitor is focused (Quickshell's cached value can be stale), then map.
        if (!monitors.running)
            monitors.running = true;
    }
    function map(name) {
        target = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
        open = true;
        slideIn.restart(); // after the window maps, so the slide animates
    }

    Process {
        id: monitors
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                try {
                    name = JSON.parse(text).find(m => m.focused)?.name ?? "";
                } catch (e) {}
                shell.map(name);
            }
        }
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
    // Unmap once the panel has slid back into the border.
    Timer {
        id: closing
        interval: 560
        onTriggered: if (!shell.slid) shell.open = false
    }
    // Close a while after Redat goes idle, unless pinned, hovered or being typed in.
    Timer {
        interval: 9000
        running: shell.slid && !shell.pinned && !shell.typing && Redat.state === "idle" && !Redat.paused && !win.hovered
        onTriggered: shell.hide()
    }

    Connections {
        target: Redat
        function onActivity() {
            shell.show(false);
        }
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

        readonly property bool hovered: hover.hovered
        readonly property real border: contentItem.Config.border.thickness
        readonly property real panelWidth: 1080
        readonly property real panelHeight: 340

        visible: shell.open
        screen: shell.target
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: border + panelHeight + 40
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "redat-panel"
        // Never take the keyboard when it pops up on its own (it would swallow what I'm typing
        // elsewhere); only while I'm typing in it (shortcut or a click on the text box).
        WlrLayershell.keyboardFocus: shell.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        // Only the panel takes input; the rest of the strip stays click-through.
        mask: Region {
            item: maskItem
        }

        Item {
            id: maskItem
            x: panel.x
            y: win.border
            width: panel.width
            height: Math.max(0, panel.y + panel.height)
        }

        // Everything below the border line. The blob strip that stands in for the border sits above
        // this and is clipped away, so only the smooth join (and the panel) is drawn here.
        Item {
            id: below

            y: win.border
            width: parent.width
            height: parent.height - win.border
            clip: true

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Theme.shadow, 0.7)
                }

                BlobGroup {
                    id: blobs
                    color: Qt.alpha(Theme.surfaceBase, Tokens.transparency.enabled ? Tokens.transparency.base : 1)
                    smoothing: win.contentItem.Config.border.smoothing
                }
                BlobRect {
                    group: blobs
                    x: panel.x - 70
                    y: -300
                    implicitWidth: panel.width + 140
                    implicitHeight: 300
                    radius: 0
                }
                BlobRect {
                    id: panelBlob
                    group: blobs
                    x: panel.x
                    y: panel.y
                    implicitWidth: panel.width
                    implicitHeight: panel.height
                    radius: Tokens.rounding.extraLarge
                    deformScale: (0.1 * win.contentItem.Config.appearance.deformScale) / 10000
                }
            }

            Item {
                id: panel

                x: (parent.width - width) / 2
                y: shell.slid ? 0 : -height - 5
                width: win.panelWidth
                height: win.panelHeight
                opacity: shell.slid ? 1 : 0
                transform: Matrix4x4 {
                    matrix: panelBlob.deformMatrix
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Tokens.anim.durations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.anim.expressiveDefaultSpatial.bezierCurve
                    }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Tokens.anim.durations.normal }
                }

                HoverHandler {
                    id: hover
                }

                // Drifting shapes, clipped to the panel's rounded shape.
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: roundMask
                    }
                    BackgroundShapes {
                        anchors.fill: parent
                        running: Redat.state !== "idle"
                    }
                }
                Rectangle {
                    id: roundMask
                    anchors.fill: parent
                    radius: Tokens.rounding.extraLarge
                    visible: false
                    layer.enabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.extraLarge

                    // ── Avatar + visualiser (the "cover art")
                    AvatarVisualiser {
                        Layout.fillHeight: true
                        implicitWidth: 300
                        coverSize: 196
                    }

                    // ── AI info + controls (the "track info")
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Tokens.spacing.extraSmall

                        Text {
                            Layout.fillWidth: true
                            text: "ረዳት · Redat"
                            color: Theme.onSurface
                            font: Tokens.font.title.large
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: !Redat.online ? "አልተገናኘም · offline (redat start)"
                                : Redat.paused ? "ቆሟል · paused"
                                : Redat.state === "listening" ? (Redat.followUp ? "ይቀጥሉ… · follow-up" : "እያዳመጥኩ ነው… · listening")
                                : Redat.state === "thinking" ? "እያሰብኩ ነው… · thinking"
                                : Redat.state === "speaking" ? "እየተናገርኩ ነው… · speaking"
                                : "ዝግጁ · ready"
                            color: !Redat.online ? Theme.error : Theme.onSurfaceVariant
                            font: Tokens.font.title.medium
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Redat.state === "thinking" && Redat.runningTool ? "⌘ " + Redat.runningTool
                                : "Claude " + Redat.model + " · " + Redat.voice + (Redat.muted ? " · 🔕" : "")
                            color: Theme.secondary
                            font: Tokens.font.title.medium
                            elide: Text.ElideRight
                        }

                        // Reply speed, in place of the track progress bar.
                        RowLayout {
                            Layout.topMargin: Tokens.spacing.extraLargeIncreased
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Text {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignHCenter
                                text: (speed.dragging ? 0.5 + speed.dragValue * 1.5 : Redat.speed).toFixed(2) + "×"
                                color: Theme.onSurfaceVariant
                                font: Tokens.font.label.medium
                            }
                            WavySlider {
                                id: speed
                                Layout.fillWidth: true
                                value: (Redat.speed - 0.5) / 1.5
                                animate: Redat.state === "speaking" && !Redat.paused
                                enabled: Redat.online
                                onMoved: v => Redat.send("speed", String(Math.round((0.5 + v * 1.5) * 20) / 20))
                            }
                            Text {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignHCenter
                                text: "2.00×"
                                color: Theme.onSurfaceVariant
                                font: Tokens.font.label.medium
                            }
                        }

                        // Controls, in place of shuffle / previous / play / next / repeat.
                        RowLayout {
                            id: controls

                            readonly property bool talking: Redat.state === "speaking" || Redat.state === "thinking" || Redat.paused

                            Layout.topMargin: Tokens.spacing.largeIncreased
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Tokens.spacing.extraSmall

                            TonalButton {
                                icon: Redat.muted ? "notifications_off" : "notifications_active"
                                tip: Redat.muted ? "Wake word off" : "Wake word on"
                                checked: Redat.muted
                                enabled: Redat.online
                                implicitWidth: 44
                                iconSize: 20
                                onClicked: Redat.send("mute")
                            }
                            TonalButton {
                                icon: "stop"
                                tip: "Stop"
                                enabled: Redat.online && Redat.state !== "idle"
                                iconSize: 28
                                onClicked: Redat.send("cancel")
                            }
                            TonalButton {
                                filled: true
                                implicitWidth: 76
                                implicitHeight: 56
                                iconSize: 32
                                enabled: Redat.online
                                icon: controls.talking ? (Redat.paused ? "play_arrow" : "pause") : "mic"
                                tip: controls.talking ? (Redat.paused ? "Resume" : "Pause") : Redat.state === "listening" ? "Stop recording" : "Listen (SUPER+Y)"
                                onClicked: controls.talking ? Redat.send("pause") : Redat.send("listen")
                            }
                            TonalButton {
                                icon: "mic"
                                tip: "Interrupt and listen"
                                checked: Redat.state === "listening"
                                enabled: Redat.online
                                iconSize: 28
                                onClicked: Redat.send("listen")
                            }
                            TonalButton {
                                icon: "restart_alt"
                                tip: "New conversation"
                                enabled: Redat.online
                                implicitWidth: 44
                                iconSize: 20
                                onClicked: Redat.send("reset")
                            }
                        }
                    }

                    // ── Chat (the "lyrics")
                    ColumnLayout {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 360
                        spacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small
                            Icon {
                                text: "forum"
                                size: 22
                                color: Theme.onSurface
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "ውይይት · Chat"
                                color: Theme.onSurface
                                font: Tokens.font.title.medium
                            }
                            TonalButton {
                                icon: "keep"
                                tip: shell.pinned ? "Unpin" : "Keep open"
                                checked: shell.pinned
                                implicitWidth: 36
                                implicitHeight: 36
                                iconSize: 18
                                onClicked: shell.pinned = !shell.pinned
                            }
                            TonalButton {
                                icon: "close"
                                tip: "Close (Esc)"
                                implicitWidth: 36
                                implicitHeight: 36
                                iconSize: 18
                                onClicked: shell.hide()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Fade the top and bottom edges like the lyrics list.
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
                                    GradientStop { position: 0.12; color: "white" }
                                    GradientStop { position: 0.94; color: "white" }
                                    GradientStop { position: 1; color: "transparent" }
                                }
                            }

                            ListView {
                                id: chat
                                anchors.fill: parent
                                model: Redat.turns
                                spacing: 14
                                topMargin: 18
                                bottomMargin: 12
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

                            Text {
                                anchors.centerIn: parent
                                visible: Redat.turns.count === 0
                                horizontalAlignment: Text.AlignHCenter
                                text: "«ረዳት» ይበሉ ወይም ይጻፉ\nSay “ረዳት” or type below"
                                color: Theme.onSurfaceVariant
                                font: Tokens.font.body.medium
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: Redat.lastError !== ""
                            text: "⚠ " + Redat.lastError
                            color: Theme.error
                            elide: Text.ElideRight
                            font: Tokens.font.label.medium
                        }

                        // Text box, in place of the player selector.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 44
                                topLeftRadius: 22
                                bottomLeftRadius: 22
                                topRightRadius: 8
                                bottomRightRadius: 8
                                color: Theme.secondaryContainer
                                border.width: shell.typing ? 2 : 0
                                border.color: Theme.primary

                                TapHandler {
                                    onTapped: shell.typing = true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    Icon {
                                        text: "keyboard"
                                        size: 20
                                        color: Theme.onSecondaryContainer
                                    }
                                    TextInput {
                                        id: input
                                        Layout.fillWidth: true
                                        color: Theme.onSecondaryContainer
                                        selectionColor: Theme.primary
                                        selectedTextColor: Theme.onPrimary
                                        font: Tokens.font.body.large
                                        clip: true
                                        focus: true

                                        function submit() {
                                            const t = text.trim();
                                            if (!t)
                                                return;
                                            Redat.send("say", t, { silent: !shell.speakReplies });
                                            text = "";
                                            shell.typing = false;
                                        }

                                        onAccepted: submit()
                                        Keys.onEscapePressed: {
                                            text = "";
                                            shell.hide();
                                        }
                                        // A click straight on the text also starts typing.
                                        TapHandler {
                                            onTapped: shell.typing = true
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !input.text && !input.preeditText
                                            text: "ይጻፉ… · type a message"
                                            color: Theme.onSecondaryContainer
                                            opacity: 0.6
                                            font: input.font
                                        }
                                    }
                                    Icon {
                                        text: "arrow_upward"
                                        size: 20
                                        visible: input.text.trim() !== ""
                                        color: Theme.primary
                                        TapHandler {
                                            onTapped: input.submit()
                                        }
                                    }
                                }
                            }
                            // Spoken vs silent replies for typed turns (the split-button half).
                            Rectangle {
                                implicitWidth: 44
                                implicitHeight: 44
                                topLeftRadius: 8
                                bottomLeftRadius: 8
                                topRightRadius: 22
                                bottomRightRadius: 22
                                color: Theme.secondaryContainer
                                Icon {
                                    anchors.centerIn: parent
                                    text: shell.speakReplies ? "volume_up" : "volume_off"
                                    size: 20
                                    color: Theme.onSecondaryContainer
                                }
                                MouseArea {
                                    id: voiceToggle
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shell.speakReplies = !shell.speakReplies
                                }
                                ToolTipLite {
                                    text: shell.speakReplies ? "Typed turns: spoken reply" : "Typed turns: silent reply"
                                    shown: voiceToggle.containsMouse
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
