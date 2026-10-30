import QtQuick
import QtQuick.Layouts
import qs.config

// One stretch of the hairline between two words.
Rectangle {
    property int length: 22

    implicitHeight: 1
    Layout.preferredWidth: length
    Layout.alignment: Qt.AlignVCenter
    color: Theme.rule

    G {}
}
