import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Hairline's notifications, opened by clicking the word on the line: the
// same list the Margin column shows, newest first.
PanelWindow {
    id: popup

    required property var owner
    required property var line

    visible: Mode.popup === "notifications" && !Mode.margin && Notifs.entries.length > 0
    anchors {
        top: true
        left: true
    }
    margins {
        top: Theme.lineY + Theme.lineHeight + 6
        // Keep it on screen: the notifications word sits near the right edge.
        left: Math.max(8, Math.min(popup.owner.notifsX - 16, popup.screen.width - implicitWidth - Theme.lineX))
    }
    implicitWidth: 440
    implicitHeight: body.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "vellum-popup"

    HyprlandFocusGrab {
        active: popup.visible
        windows: [popup, popup.line]
        onCleared: Mode.popup = ""
    }

    Rectangle {
        id: body

        width: parent.width
        height: rows.implicitHeight + 18
        radius: 12
        color: Qt.rgba(0.102, 0.11, 0.22, 0.72)
        border.width: 1
        border.color: Qt.rgba(0.804, 0.839, 0.957, 0.22)

        Column {
            id: rows

            y: 8
            width: parent.width

            Repeater {
                model: Notifs.entries.slice(0, 12)

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    width: rows.width
                    height: 54

                    Label {
                        x: 16
                        y: 10
                        width: 66
                        text: Time.when(row.modelData.time)
                        font.pixelSize: 13
                        color: Theme.yellow
                        opacity: 0.85
                    }

                    Label {
                        x: 90
                        y: 9
                        width: parent.width - 90 - 16
                        elide: Text.ElideRight
                        text: row.modelData.label
                        font.pixelSize: 13
                    }

                    Label {
                        x: 90
                        y: 29
                        width: parent.width - 90 - 16
                        elide: Text.ElideRight
                        text: row.modelData.detail
                        font.pixelSize: 12
                        color: Theme.overlay1
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        visible: row.index < Math.min(12, Notifs.entries.length) - 1
                        color: Qt.rgba(0.804, 0.839, 0.957, 0.1)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                Notifs.dismiss(row.modelData);
                                return;
                            }
                            Notifs.activate(row.modelData);
                            Mode.popup = "";
                        }
                    }
                }
            }

            Item {
                width: rows.width
                height: 26

                Label {
                    x: 16
                    y: 9
                    text: Notifs.entries.length > 12 ? `${Notifs.entries.length - 12} more · right-click to dismiss` : "right-click to dismiss"
                    font.pixelSize: 11
                    color: Theme.overlay0
                }

                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    y: 9
                    text: "clear"
                    font.pixelSize: 11
                    color: clearArea.containsMouse ? Theme.text : Theme.overlay1

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Notifs.clear();
                            Mode.popup = "";
                        }
                    }
                }
            }
        }
    }
}
