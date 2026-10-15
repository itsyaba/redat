//@ pragma UseQApplication
// Renders the panel with made-up data to a PNG, for working on the look without opening the real
// panel. The window is a 1x1 transparent click-through overlay, so nothing shows on screen; the grab
// renders the full-size item anyway. Point XDG_RUNTIME_DIR elsewhere so it doesn't attach to the
// live daemon (and give WAYLAND_DISPLAY as an absolute path):
//   XDG_RUNTIME_DIR=/tmp/x WAYLAND_DISPLAY=$XDG_RUNTIME_DIR/wayland-1 REDAT_PREVIEW=speaking \
//     REDAT_PREVIEW_OUT=/tmp/p.png qs -p panel/preview.qml
// Scenes: empty, listening, thinking, speaking.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.services
import qs.components

ShellRoot {
    id: root

    readonly property string scene: Quickshell.env("REDAT_PREVIEW") || "speaking"

    QtObject {
        id: host
        property bool pinned: false
        property bool typing: false
        property bool speakReplies: true
        function hide() {}
    }

    PanelWindow {
        id: win
        anchors.top: true
        anchors.left: true
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "redat-preview"
        color: "transparent"
        mask: Region {}

        Rectangle {
            id: frame
            x: 20
            y: 20
            width: 1120
            height: 384
            radius: Tokens.rounding.extraLarge
            color: Qt.alpha(Theme.surfaceBase, 0.95)
            Dashboard {
                anchors.fill: parent
                host: host
            }
        }
    }

    function ev(e) {
        Redat.onEvent(e);
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            Redat.online = true;
            const st = { type: "state", state: "idle", muted: false, paused: false, followUp: false, speed: 1.15, model: "sonnet", voice: "yohanes-calm" };
            ev(Object.assign({}, st, { state: root.scene === "empty" ? "idle" : root.scene }));
            if (root.scene === "empty")
                return;
            ev({ type: "turn", turn: { id: 1, source: "voice", heard: "ሰዓቱ ስንት ነው?", text: "አሁን ከቀኑ 8 ሰዓት ከ15 ደቂቃ ነው።", done: true, tools: [{ id: "a", name: "Bash", input: "date '+%H:%M'", output: "14:15", ms: 12 }] } });
            if (root.scene === "listening") {
                ev({ type: "turn", turn: { id: 2, source: "voice", heard: "", text: "", done: false, tools: [] } });
                return;
            }
            ev({ type: "turn", turn: { id: 2, source: "typed", heard: "የዛሬ የአየር ሁኔታ በአዲስ አበባ እንዴት ነው?", text: "", done: false, tools: [] } });
            ev({ type: "tool", turnId: 2, tool: { id: "b", name: "Bash", input: "curl -s 'wttr.in/Addis+Ababa?format=3'" } });
            if (root.scene === "thinking")
                return;
            ev({ type: "toolResult", turnId: 2, id: "b", output: "Addis Ababa: ⛅️ +22°C", error: false, ms: 840 });
            ev({ type: "delta", id: 2, text: "ዛሬ በአዲስ አበባ ከፊል ደመናማ ነው፣ ሙቀቱ 22 ዲግሪ ሴልሺየስ ነው። ምሽት ላይ ትንሽ ዝናብ ሊኖር ይችላል፣" });
        }
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: frame.grabToImage(r => {
                r.saveToFile(Quickshell.env("REDAT_PREVIEW_OUT") || "/tmp/redat-preview.png");
                Qt.quit();
            })
    }
}
