import QtQuick
import qs.services

// A Material Symbols Rounded glyph by name, e.g. "mic".
Text {
    property real size: 20
    property bool filled: false

    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: ({ FILL: filled ? 1 : 0, wght: 450, opsz: 24 })
    color: Theme.fgSurface
    renderType: Text.NativeRendering
}
