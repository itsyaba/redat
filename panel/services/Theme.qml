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
    // Not "onSurface" etc.: QML reads a property named on<Capital>… as a signal handler, and those
    // came out black.
    readonly property color fgSurface: col("onSurface", "#dce8e6")
    readonly property color fgSurfaceVariant: col("onSurfaceVariant", "#bec9c7")
    readonly property color outline: col("outline", "#889391")
    readonly property color outlineVariant: col("outlineVariant", "#3f4948")
    readonly property color primary: col("primary", "#80d5cf")
    readonly property color fgPrimary: col("onPrimary", "#003734")
    readonly property color primaryContainer: col("primaryContainer", "#00504c")
    readonly property color fgPrimaryContainer: col("onPrimaryContainer", "#9cf2eb")
    readonly property color secondaryContainer: col("secondaryContainer", "#324b49")
    readonly property color fgSecondaryContainer: col("onSecondaryContainer", "#cce8e5")
    readonly property color tertiary: col("tertiary", "#a3cbe8")
    readonly property color secondary: col("secondary", "#b0ccc9")
    readonly property color tertiaryContainer: col("tertiaryContainer", "#1e4a60")
    readonly property color fgTertiaryContainer: col("onTertiaryContainer", "#c5e7ff")
    readonly property color surfaceBase: col("surface", "#0a0f0f")
    readonly property color shadow: col("shadow", "#000000")
    readonly property color error: col("error", "#ffb4ab")
    readonly property color errorContainer: col("errorContainer", "#93000a")

    // Caelestia's UI font isn't installed system-wide; it ships with the shell, so load it from there.
    readonly property string sans: gsf.status === FontLoader.Ready ? gsf.name : "Noto Sans"
    // Ge'ez script: Qt's fallback picks a thin, small face, so Amharic text names this font explicitly.
    readonly property string font: "Noto Sans Ethiopic"
    readonly property string mono: "CaskaydiaCove Nerd Font"
    readonly property string icons: "Material Symbols Rounded"
    readonly property int radius: 24

    FontLoader {
        id: gsf
        source: "file:///etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
    }

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
