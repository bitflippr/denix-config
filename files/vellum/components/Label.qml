import QtQuick
import qs.config

// Text in the shell's one typeface. Distance-field rendering keeps it sharp
// at any scale, so a piece can shrink from the column into the line.
Text {
    font.family: Theme.font
    renderType: Text.QtRendering
    color: Theme.text
}
