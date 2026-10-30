import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// One screen of vellum, on two layers.
//
// The ground sits below the windows, on the wallpaper: the Margin column,
// the Hairline line and the scrim, with the parts of each layout that only
// one mode has. Windows slide over it when the mode changes, as if the text
// were printed on the wallpaper. It also takes every click.
//
// The pieces layer sits above the windows and lets every click through. It
// holds only the shared pieces (clock, spaces, threads, track, vol), which
// fly between their spots in the two layouts during the morph.
Scope {
    id: root

    required property ShellScreen screen

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var spaces: Spaces.list(monitor)
    readonly property int activeIndex: spaces.findIndex(s => s.active)
    readonly property var focused: Spaces.focusedTitle()
    readonly property real threadsX: {
        Morph.tick;
        return lineThreads.mapToItem(canvas, 0, 0).x;
    }
    readonly property real todayX: {
        Morph.tick;
        return lineToday.mapToItem(canvas, 0, 0).x;
    }

    Binding {
        target: Media
        property: "tracking"
        value: Mode.margin && Media.active
    }

    Reserve {
        screen: root.screen
    }

    ThreadsPopup {
        screen: root.screen
        owner: root
        line: ground
    }

    TodayPopup {
        screen: root.screen
        owner: root
        line: ground
    }

    PanelWindow {
        id: ground

        screen: root.screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "vellum"
        color: "transparent"
        mask: Region {
            item: Mode.margin ? columnHit : lineHit
        }

        // Darkening behind the column so it reads on any part of the
        // wallpaper: even across the column, then fading out behind the
        // window glass so there is no hard edge.
        Rectangle {
            width: 460
            height: parent.height
            opacity: Mode.ready && Mode.margin ? 1 : 0

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.rgba(0.067, 0.067, 0.106, 0.74)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.rgba(0.067, 0.067, 0.106, 0.66)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0.067, 0.067, 0.106, 0)
                }
            }

            Behavior on opacity {
                enabled: Mode.morphing
                NumberAnimation {
                    duration: Theme.morphMs
                }
            }
        }

        // The same darkening behind the line in Hairline.
        Rectangle {
            width: parent.width
            height: 88
            opacity: Mode.ready && !Mode.margin ? 1 : 0

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0.067, 0.067, 0.106, 0.74)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.rgba(0.067, 0.067, 0.106, 0.66)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0.067, 0.067, 0.106, 0)
                }
            }

            Behavior on opacity {
                enabled: Mode.morphing
                NumberAnimation {
                    duration: Theme.morphMs
                }
            }
        }

        Item {
            id: canvas

            anchors.fill: parent
            opacity: Mode.ready ? 1 : 0

            // A soft dark halo so text stays legible on any part of the wallpaper.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.55
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
            }

            Item {
                id: columnHit
                width: Theme.columnX + Theme.columnWidth + 12
                height: parent.height
            }

            Item {
                id: lineHit
                width: parent.width
                height: Theme.lineY + Theme.lineHeight + 4
            }

            // --- Margin: the column -------------------------------------------

            ColumnLayout {
                id: column

                x: Theme.columnX
                y: Theme.edgeY
                width: Theme.columnWidth
                height: ground.height - 2 * Theme.edgeY
                spacing: 0
                enabled: Mode.margin
                opacity: Mode.margin ? 1 : 0

                Behavior on opacity {
                    enabled: Mode.morphing
                    SequentialAnimation {
                        PauseAnimation {
                            duration: Mode.margin ? 200 : 0
                        }
                        NumberAnimation {
                            duration: Mode.margin ? 240 : 170
                        }
                    }
                }

                G {}

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: colClock.height - 6

                    G {}

                    P {
                        id: colClock
                        interactive: true
                        onClicked: Mode.toggle()
                        x: -3
                        y: -3
                        text: Time.clock
                        font.pixelSize: 72
                        font.weight: Font.Light
                        font.letterSpacing: -1.44
                    }

                    P {
                        id: colAmpm
                        interactive: true
                        onClicked: Mode.toggle()
                        anchors.left: colClock.right
                        anchors.leftMargin: 8
                        anchors.baseline: colClock.baseline
                        text: Time.ampm
                        font.pixelSize: 15
                        font.weight: Font.Light
                        color: Theme.subtext1
                    }
                }

                P {
                    id: colDate
                    interactive: true
                    onClicked: Mode.toggle()
                    Layout.topMargin: 12
                    text: Time.date
                    font.pixelSize: 14
                    color: Theme.subtext1
                }

                P {
                    id: colWeather
                    Layout.topMargin: 5
                    visible: Weather.text !== ""
                    text: Weather.text
                    font.pixelSize: 13
                    color: Theme.overlay2
                }

                P {
                    id: colSpacesLabel
                    Layout.topMargin: 44
                    Layout.bottomMargin: 12
                    text: "spaces"
                    font.pixelSize: 12
                    color: Theme.overlay1
                }

                Repeater {
                    id: colSpaces
                    model: root.spaces

                    Item {
                        id: spaceRow

                        required property var modelData
                        property alias num: num
                        property alias marker: marker

                        Layout.fillWidth: true
                        Layout.preferredHeight: 27

                        G {}

                        Rectangle {
                            id: marker
                            x: -14
                            y: 5
                            width: 2
                            height: 17
                            radius: 1
                            color: Theme.lavender
                            opacity: 0
                            visible: spaceRow.modelData.active

                            G {}
                        }

                        P {
                            id: num
                            anchors.verticalCenter: parent.verticalCenter
                            text: spaceRow.modelData.id
                            font.pixelSize: 14
                            color: spaceRow.modelData.active ? Theme.lavender : Theme.overlay0
                        }

                        Label {
                            x: 24
                            width: parent.width - 24
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: spaceRow.modelData.name
                            font.pixelSize: 14
                            color: spaceRow.modelData.active ? Theme.text : Theme.subtext0
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: spaceRow.modelData.workspace.activate()
                        }
                    }
                }

                P {
                    id: colThreadsLabel
                    Layout.topMargin: 44
                    Layout.bottomMargin: 12
                    visible: Threads.list.length > 0
                    text: "threads"
                    font.pixelSize: 12
                    color: Theme.overlay1
                }

                Repeater {
                    id: colThreads
                    model: Threads.list

                    Item {
                        id: threadRow

                        required property var modelData
                        property alias dot: dot
                        // A task sits slightly in from the thread it belongs to.
                        readonly property int indent: modelData.child ? 12 : 0

                        Layout.fillWidth: true
                        Layout.preferredHeight: 41

                        G {}

                        Rectangle {
                            id: dot
                            x: threadRow.indent
                            y: 5
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.kindColor(threadRow.modelData.kind)
                            opacity: 0

                            G {}
                        }

                        Label {
                            x: 24 + threadRow.indent
                            width: parent.width - 24 - threadRow.indent
                            elide: Text.ElideRight
                            text: threadRow.modelData.title
                            font.pixelSize: 13
                        }

                        Label {
                            x: 24
                            y: 18
                            width: parent.width - 24
                            elide: Text.ElideRight
                            text: [threadRow.modelData.project, threadRow.modelData.label].filter(s => s).join(" · ")
                            font.pixelSize: 12
                            color: Theme.overlay1
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Threads.open(threadRow.modelData.id, threadRow.modelData.environmentId)
                        }
                    }
                }

                Label {
                    Layout.topMargin: 44
                    Layout.bottomMargin: 12
                    visible: Media.active
                    text: "playing"
                    font.pixelSize: 12
                    color: Theme.overlay1
                }

                P {
                    id: colTrack
                    interactive: true
                    onClicked: Media.player?.togglePlaying()
                    Layout.maximumWidth: Theme.columnWidth
                    visible: Media.active
                    elide: Text.ElideRight
                    text: Media.title
                    font.pixelSize: 14
                }

                P {
                    id: colArtist
                    interactive: true
                    onClicked: Media.player?.togglePlaying()
                    Layout.topMargin: 4
                    Layout.maximumWidth: Theme.columnWidth
                    visible: Media.active && Media.artist !== ""
                    elide: Text.ElideRight
                    text: Media.artist
                    font.pixelSize: 13
                    color: Theme.overlay2
                }

                Item {
                    Layout.topMargin: 16
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: Media.active && Media.length > 0

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0.804, 0.839, 0.957, 0.2)
                    }

                    Rectangle {
                        id: progress
                        height: 1
                        width: parent.width * Math.min(1, Media.position / Math.max(1, Media.length))
                        color: Theme.lavender

                        Rectangle {
                            x: parent.width - 2
                            y: -2
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Theme.lavender
                        }
                    }
                }

                Item {
                    Layout.topMargin: 7
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14
                    visible: Media.active && Media.length > 0

                    Label {
                        text: Media.stamp(Media.position)
                        font.pixelSize: 11
                        color: Theme.overlay0
                    }

                    Label {
                        anchors.right: parent.right
                        text: Media.stamp(Media.length)
                        font.pixelSize: 11
                        color: Theme.overlay0
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                P {
                    id: colTodayLabel
                    Layout.bottomMargin: 12
                    visible: Today.entries.length > 0
                    text: "today"
                    font.pixelSize: 12
                    color: Theme.overlay1
                }

                Repeater {
                    // Newest at the bottom; older entries rise and fade.
                    model: Today.entries.slice(0, 6).reverse()

                    Item {
                        id: entry

                        required property var modelData
                        required property int index
                        readonly property int age: Math.min(6, Today.entries.length) - 1 - index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 37
                        Layout.topMargin: index === 0 ? 0 : 14
                        opacity: [1, 0.78, 0.56, 0.38, 0.22, 0.14][age] ?? 0.14

                        Label {
                            width: 56
                            text: Theme.time12(entry.modelData.time)
                            font.pixelSize: 13
                            color: Theme.yellow
                            opacity: 0.85
                        }

                        Label {
                            x: 68
                            width: parent.width - 68
                            elide: Text.ElideRight
                            text: entry.modelData.label
                            font.pixelSize: 13
                        }

                        Label {
                            x: 68
                            y: 19
                            width: parent.width - 68
                            elide: Text.ElideRight
                            text: entry.modelData.detail
                            font.pixelSize: 13
                            color: Theme.overlay2
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Today.activate(entry.modelData)
                        }
                    }
                }

                Rectangle {
                    Layout.topMargin: 20
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.faintRule
                }

                Item {
                    Layout.topMargin: 12
                    Layout.fillWidth: true
                    Layout.preferredHeight: 19

                    G {}

                    P {
                        id: colVolLabel
                        interactive: true
                        onClicked: Audio.toggleMute()
                        onWheel: delta => Audio.nudge(delta > 0 ? 0.05 : -0.05)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "vol"
                        font.pixelSize: 12
                        color: Theme.overlay1
                    }

                    P {
                        id: colVol
                        interactive: true
                        onClicked: Audio.toggleMute()
                        onWheel: delta => Audio.nudge(delta > 0 ? 0.05 : -0.05)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Audio.text
                        font.pixelSize: 12
                        color: Theme.subtext0
                    }
                }
            }

            // --- Hairline: the line --------------------------------------------

            Item {
                id: line

                x: Theme.lineX
                y: Theme.lineY
                width: ground.width - 2 * Theme.lineX
                height: Theme.lineHeight
                enabled: !Mode.margin
                opacity: Mode.margin ? 0 : 1

                Behavior on opacity {
                    enabled: Mode.morphing
                    SequentialAnimation {
                        PauseAnimation {
                            duration: Mode.margin ? 0 : 170
                        }
                        NumberAnimation {
                            duration: Mode.margin ? 170 : 270
                        }
                    }
                }

                G {}

                // Outside the row so they cannot feed back into the row's width.
                MouseArea {
                    id: todayArea
                    z: 1
                    x: lineToday.x
                    width: lineToday.width
                    height: parent.height
                    visible: lineToday.visible
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Mode.togglePopup("today")
                }

                MouseArea {
                    z: 1
                    x: lineThreads.x
                    width: lineThreads.width
                    height: parent.height
                    visible: lineThreads.visible
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Mode.togglePopup("threads")
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    G {}

                    Seg {
                        length: 16
                    }

                    Word {
                        P {
                            id: lineSpacesLabel
                            text: "spaces"
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }

                        Repeater {
                            id: lineSpaces
                            model: root.spaces

                            P {
                                id: lineNum

                                required property var modelData
                                property alias marker: lineMarker

                                interactive: true
                                onClicked: modelData.workspace.activate()
                                text: modelData.id
                                font.pixelSize: Theme.lineSize
                                color: modelData.active ? Theme.lavender : Theme.subtext0

                                Rectangle {
                                    id: lineMarker
                                    y: parent.height + 1
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: Theme.lavender
                                    visible: lineNum.modelData.active
                                }
                            }
                        }
                    }

                    Seg {
                        visible: lineThreads.visible
                    }

                    Word {
                        id: lineThreads

                        visible: Threads.list.length > 0

                        P {
                            id: lineThreadsLabel
                            text: "threads"
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }

                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter

                            G {}

                            Repeater {
                                id: lineDots
                                model: Threads.list

                                Rectangle {
                                    required property var modelData

                                    width: 7
                                    height: 7
                                    radius: 3.5
                                    color: Theme.kindColor(modelData.kind)
                                    opacity: 0

                                    G {}
                                }
                            }
                        }
                    }

                    Seg {
                        Layout.fillWidth: true
                    }

                    Word {
                        visible: root.focused !== null

                        Label {
                            text: root.focused?.app ?? ""
                            font.pixelSize: Theme.lineSize
                            color: Theme.subtext0
                        }

                        Label {
                            width: Math.min(implicitWidth, 520)
                            elide: Text.ElideRight
                            text: root.focused?.title ?? ""
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }
                    }

                    Seg {
                        Layout.fillWidth: true
                    }

                    Word {
                        visible: Media.active

                        P {
                            id: lineTrack
                        interactive: true
                        onClicked: Media.player?.togglePlaying()
                            width: Math.min(implicitWidth, 320)
                            elide: Text.ElideRight
                            text: Media.title
                            font.pixelSize: Theme.lineSize
                            color: Theme.subtext0
                        }

                        Label {
                            visible: Media.artist !== ""
                            text: "·"
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }

                        P {
                            id: lineArtist
                        interactive: true
                        onClicked: Media.player?.togglePlaying()
                            visible: Media.artist !== ""
                            width: Math.min(implicitWidth, 220)
                            elide: Text.ElideRight
                            text: Media.artist
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }
                    }

                    Seg {
                        visible: Media.active
                    }

                    Word {
                        P {
                            id: lineVolLabel
                        interactive: true
                        onClicked: Audio.toggleMute()
                        onWheel: delta => Audio.nudge(delta > 0 ? 0.05 : -0.05)
                            text: "vol"
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }

                        P {
                            id: lineVol
                        interactive: true
                        onClicked: Audio.toggleMute()
                        onWheel: delta => Audio.nudge(delta > 0 ? 0.05 : -0.05)
                            text: Audio.text
                            font.pixelSize: Theme.lineSize
                            color: Theme.subtext0
                        }
                    }

                    Seg {}

                    Word {
                        visible: Weather.text !== ""

                        P {
                            id: lineWeather
                            text: Weather.text
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }
                    }

                    Seg {
                        visible: Weather.text !== ""
                    }

                    Word {
                        id: lineToday

                        visible: Today.entries.length > 0

                        P {
                            id: lineTodayLabel
                            text: "today"
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }

                        EventMark {
                            anchors.verticalCenter: parent.verticalCenter
                            hovered: todayArea.containsMouse
                        }
                    }

                    Seg {
                        visible: lineToday.visible
                    }

                    Word {
                        P {
                            id: lineDate
                        interactive: true
                        onClicked: Mode.toggle()
                            text: Time.date
                            font.pixelSize: Theme.lineSize
                            color: Theme.overlay1
                        }

                        P {
                            id: lineClock
                        interactive: true
                        onClicked: Mode.toggle()
                            text: Time.clock
                            font.pixelSize: Theme.lineSize
                            font.weight: Font.Light
                            font.letterSpacing: -0.28
                            color: Theme.text
                        }

                        P {
                            id: lineAmpm
                        interactive: true
                        onClicked: Mode.toggle()
                            text: Time.ampm
                            font.pixelSize: Theme.lineSize
                            font.weight: Font.Light
                            color: Theme.subtext1
                        }
                    }

                    Seg {
                        length: 16
                    }
                }
            }
        }
    }

    PanelWindow {
        id: pieces

        screen: root.screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "vellum-pieces"
        color: "transparent"
        mask: Region {}

        Item {
            anchors.fill: parent
            opacity: Mode.ready ? 1 : 0

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.55
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
            }

            // --- Shared pieces -------------------------------------------------

            Actor {
                space: canvas
                marginTarget: colClock
                hairlineTarget: lineClock
                text: Time.clock
                font.pixelSize: 72
                font.weight: Font.Light
                font.letterSpacing: -1.44
            }

            Actor {
                space: canvas
                marginTarget: colAmpm
                hairlineTarget: lineAmpm
                text: Time.ampm
                font.pixelSize: 15
                font.weight: Font.Light
            }

            Actor {
                space: canvas
                marginTarget: colDate
                hairlineTarget: lineDate
                text: Time.date
                font.pixelSize: 14
            }

            Actor {
                space: canvas
                marginTarget: colWeather
                hairlineTarget: lineWeather
                text: Weather.text
                font.pixelSize: 13
            }

            Actor {
                space: canvas
                marginTarget: colSpacesLabel
                hairlineTarget: lineSpacesLabel
                text: "spaces"
                font.pixelSize: 12
            }

            Repeater {
                model: root.spaces

                Actor {
                    required property var modelData
                    required property int index

                    space: canvas
                    marginTarget: {
                        Morph.tick;
                        return colSpaces.itemAt(index)?.num ?? null;
                    }
                    hairlineTarget: {
                        Morph.tick;
                        return lineSpaces.itemAt(index) ?? null;
                    }
                    text: modelData.id
                    font.pixelSize: 14
                }
            }

            BoxActor {
                space: canvas
                marginTarget: {
                    Morph.tick;
                    return colSpaces.itemAt(root.activeIndex)?.marker ?? null;
                }
                hairlineTarget: {
                    Morph.tick;
                    return lineSpaces.itemAt(root.activeIndex)?.marker ?? null;
                }
            }

            Actor {
                space: canvas
                marginTarget: colThreadsLabel
                hairlineTarget: lineThreadsLabel
                text: "threads"
                font.pixelSize: 12
            }

            Repeater {
                model: Threads.list

                BoxActor {
                    required property int index

                    space: canvas
                    marginTarget: {
                        Morph.tick;
                        return colThreads.itemAt(index)?.dot ?? null;
                    }
                    hairlineTarget: {
                        Morph.tick;
                        return lineDots.itemAt(index) ?? null;
                    }
                }
            }

            Actor {
                space: canvas
                marginTarget: colTodayLabel
                hairlineTarget: lineTodayLabel
                text: "today"
                font.pixelSize: 12
            }

            Actor {
                space: canvas
                marginTarget: colTrack
                hairlineTarget: lineTrack
                width: Math.min(implicitWidth, Mode.margin ? Theme.columnWidth : 320 * 14 / Theme.lineSize)
                elide: Text.ElideRight
                text: Media.title
                font.pixelSize: 14
            }

            Actor {
                space: canvas
                marginTarget: colArtist
                hairlineTarget: lineArtist
                width: Math.min(implicitWidth, Mode.margin ? Theme.columnWidth : 220 * 13 / Theme.lineSize)
                elide: Text.ElideRight
                text: Media.artist
                font.pixelSize: 13
            }

            Actor {
                space: canvas
                marginTarget: colVolLabel
                hairlineTarget: lineVolLabel
                text: "vol"
                font.pixelSize: 12
            }

            Actor {
                space: canvas
                marginTarget: colVol
                hairlineTarget: lineVol
                text: Audio.text
                font.pixelSize: 12
            }
        }
    }
}
