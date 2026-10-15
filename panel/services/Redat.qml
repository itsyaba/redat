pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live connection to the ረዳት daemon: `subscribe` on its Unix socket, then JSON events stream in
// and commands go out on the same connection.
Singleton {
    id: root

    property bool online: sock.connected
    property string state: "idle" // idle | listening | thinking | speaking
    property bool muted: false
    property bool paused: false
    property bool followUp: false
    property real speed: 1.15
    property var levels: [] // recent mic levels (RMS) while listening
    property string lastError: ""

    // One row per turn; `tools` is a nested list of {id, name, input, output, error, ms, running}.
    readonly property ListModel turns: ListModel {}

    signal activity // something started (listening/thinking/speaking): the panel should show up

    function send(cmd, arg, extra) {
        if (!sock.connected)
            return;
        sock.write(JSON.stringify(Object.assign({ cmd: cmd, arg: arg }, extra ?? {})) + "\n");
        sock.flush();
    }

    function indexOf(id) {
        for (let i = turns.count - 1; i >= 0; i--)
            if (turns.get(i).id === id)
                return i;
        return -1;
    }

    function addTurn(t) {
        turns.append({
            id: t.id,
            source: t.source,
            heard: t.heard ?? "",
            text: t.text ?? "",
            done: !!t.done,
            error: t.error ?? "",
            tools: (t.tools ?? []).map(x => root.toolRow(x))
        });
        while (turns.count > 30)
            turns.remove(0);
    }

    function toolRow(x) {
        return {
            id: x.id,
            name: x.name,
            input: x.input ?? "",
            output: x.output ?? "",
            error: !!x.error,
            ms: x.ms ?? 0,
            running: x.output === undefined
        };
    }

    function setStatus(ev) {
        const was = state;
        state = ev.state;
        muted = ev.muted;
        paused = ev.paused;
        followUp = ev.followUp;
        speed = ev.speed;
        if (state !== "listening")
            levels = [];
        if (state !== "idle" && state !== was && !(state === "listening" && followUp))
            activity();
    }

    function onEvent(ev) {
        if (Quickshell.env("REDAT_PANEL_DEBUG"))
            console.log("redat event", ev.type, ev.state ?? "");
        let i;
        switch (ev.type) {
        case "snapshot":
            turns.clear();
            for (const t of ev.turns)
                addTurn(t);
            setStatus(ev);
            break;
        case "state":
            setStatus(ev);
            break;
        case "turn":
            addTurn(ev.turn);
            activity();
            break;
        case "heard":
            if ((i = indexOf(ev.id)) >= 0)
                turns.setProperty(i, "heard", ev.text);
            break;
        case "delta":
            if ((i = indexOf(ev.id)) >= 0)
                turns.setProperty(i, "text", turns.get(i).text + ev.text);
            break;
        case "tool":
            if ((i = indexOf(ev.turnId)) >= 0)
                turns.get(i).tools.append(toolRow(ev.tool));
            break;
        case "toolResult":
            if ((i = indexOf(ev.turnId)) >= 0) {
                const tools = turns.get(i).tools;
                for (let j = 0; j < tools.count; j++)
                    if (tools.get(j).id === ev.id) {
                        tools.set(j, { output: ev.output, error: ev.error, ms: ev.ms, running: false });
                        break;
                    }
            }
            break;
        case "done":
            if ((i = indexOf(ev.id)) >= 0) {
                turns.setProperty(i, "done", true);
                turns.setProperty(i, "error", ev.error ?? "");
                if (ev.am)
                    turns.setProperty(i, "text", ev.en ? `${ev.am}\nEN: ${ev.en}` : ev.am);
            }
            break;
        case "level":
            levels = levels.concat([ev.v]).slice(-36);
            break;
        case "reset":
            turns.clear();
            break;
        case "reply":
            if (!ev.ok) {
                lastError = ev.msg;
                errorTimer.restart();
            }
            break;
        }
    }

    Socket {
        id: sock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/redat.sock"
        connected: true
        function subscribe() {
            write('{"cmd":"subscribe"}\n');
            flush();
        }
        onConnectedChanged: {
            if (connected)
                subscribe();
            else
                root.state = "idle";
        }
        Component.onCompleted: if (connected) subscribe()
        parser: SplitParser {
            onRead: line => {
                try {
                    root.onEvent(JSON.parse(line));
                } catch (e) {
                    console.warn("redat: bad event", e, line.slice(0, 200));
                }
            }
        }
    }

    // Reconnect when the daemon (re)starts.
    Timer {
        interval: 2000
        repeat: true
        running: !sock.connected
        onTriggered: sock.connected = true
    }

    Timer {
        id: errorTimer
        interval: 4000
        onTriggered: root.lastError = ""
    }
}
