//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

// ረዳት panel: the avatar ring with its aurora, the conversation and the controls (components/
// Dashboard.qml). It grows out of the top screen border with Caelestia's own blob renderer, so it
// joins the frame like the dashboard.
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
    onTypingChanged: if (typing) dash.focusInput()
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
        readonly property real panelWidth: 1120
        readonly property real panelHeight: 384

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

                Dashboard {
                    id: dash
                    anchors.fill: parent
                    host: shell
                }
            }
        }
    }
}
