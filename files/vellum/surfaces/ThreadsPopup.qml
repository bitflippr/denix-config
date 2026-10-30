import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Hairline's threads, opened by clicking "threads" on the line.
PanelWindow {
    id: popup

    required property var owner
    required property var line

    visible: Mode.popup === "threads" && !Mode.margin && Threads.list.length > 0
    anchors {
        top: true
        left: true
    }
    margins {
        top: Theme.lineY + Theme.lineHeight + 6
        left: Math.max(8, popup.owner.threadsX - 16)
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
                model: Threads.list

                Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property int indent: modelData.child ? 14 : 0

                    width: rows.width
                    height: 54

                    Rectangle {
                        x: 16 + row.indent
                        y: 15
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.kindColor(row.modelData.kind)
                    }

                    Label {
                        x: 34 + row.indent
                        y: 9
                        width: parent.width - 34 - row.indent - status.width - 32
                        elide: Text.ElideRight
                        text: row.modelData.title
                        font.pixelSize: 13
                    }

                    Label {
                        id: status
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        y: 10
                        text: row.modelData.label
                        font.pixelSize: 12
                        color: row.modelData.kind === "fail" ? Theme.red : row.modelData.kind === "wait" ? Theme.peach : Theme.overlay1
                    }

                    Label {
                        x: 34 + row.indent
                        y: 29
                        text: [row.modelData.project, `started ${row.modelData.started}`].filter(s => s).join(" · ")
                        font.pixelSize: 12
                        color: Theme.overlay1
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        visible: row.index < Threads.list.length - 1
                        color: Qt.rgba(0.804, 0.839, 0.957, 0.1)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Threads.open(row.modelData.id, row.modelData.environmentId);
                            Mode.popup = "";
                        }
                    }
                }
            }

            Label {
                leftPadding: 16
                topPadding: 9
                text: "click a thread to open it in t3 code · settled threads stay hidden"
                font.pixelSize: 11
                color: Theme.overlay0
            }
        }
    }
}
