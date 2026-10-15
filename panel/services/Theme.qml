pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colours follow Caelestia's live Material scheme, so the panel matches the shell and the wallpaper.
Singleton {
    id: root

    property var c: ({})
    function col(name, fallback) {
        return c[name] ? "#" + c[name] : fallback;
    }

    readonly property color surface: col("surfaceContainer", "#131b1a")
    readonly property color surfaceHigh: col("surfaceContainerHigh", "#192120")
    readonly property color surfaceHighest: col("surfaceContainerHighest", "#1d2827")
    readonly property color onSurface: col("onSurface", "#dce8e6")
    readonly property color onSurfaceVariant: col("onSurfaceVariant", "#bec9c7")
    readonly property color outline: col("outline", "#889391")
    readonly property color outlineVariant: col("outlineVariant", "#3f4948")
    readonly property color primary: col("primary", "#80d5cf")
    readonly property color onPrimary: col("onPrimary", "#003734")
    readonly property color primaryContainer: col("primaryContainer", "#00504c")
    readonly property color onPrimaryContainer: col("onPrimaryContainer", "#9cf2eb")
    readonly property color secondaryContainer: col("secondaryContainer", "#324b49")
    readonly property color onSecondaryContainer: col("onSecondaryContainer", "#cce8e5")
    readonly property color tertiary: col("tertiary", "#a3cbe8")
    readonly property color secondary: col("secondary", "#b0ccc9")
    readonly property color tertiaryContainer: col("tertiaryContainer", "#1e4a60")
    readonly property color surfaceBase: col("surface", "#0a0f0f")
    readonly property color shadow: col("shadow", "#000000")
    readonly property color error: col("error", "#ffb4ab")
    readonly property color errorContainer: col("errorContainer", "#93000a")

    readonly property string font: "Noto Sans Ethiopic"
    readonly property string mono: "CaskaydiaCove Nerd Font"
    readonly property string icons: "Material Symbols Rounded"
    readonly property int radius: 24

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.c = JSON.parse(text()).colours ?? {};
            } catch (e) {
                console.warn("redat: bad scheme.json", e);
            }
        }
    }
}
