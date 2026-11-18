pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "RailLogic.js" as RailLogic
import "Logic.js" as Logic

// Below the rail: the clock and its calendar, what is playing, the tray as
// brass bell pushes, the quiet switch, and the lights.
Item {
    id: shelf
    property real u: 1
    // Which card is pinned up above the shelf: "", "calendar", "lights", or "menu".
    property string card: ""
    property var menuItem: null
    property real menuX: 0
    // Which of the lights waits for a second press.
    property string armed: ""
    property date month: new Date()
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    readonly property real phase: Logic.moon(clock.date)
    readonly property var lights: [
        {
            name: "lock",
            label: "Lock the room",
            command: [Theme.configHome + "/dotfiles/lock"]
        },
        {
            name: "sleep",
            label: "Sleep",
            command: ["systemctl", "suspend"]
        },
        {
            name: "logout",
            label: "Log out",
            command: ["swaymsg", "exit"],
            confirm: true
        },
        {
            name: "restart",
            label: "Restart",
            command: ["systemctl", "reboot"],
            confirm: true
        },
        {
            name: "shutdown",
            label: "Shut down",
            command: ["systemctl", "poweroff"],
            confirm: true
        }
    ]
    function pin(name: string): void {
        card = card === name ? "" : name;
        armed = "";
        if (card === "calendar")
            month = new Date();
    }
    function press(action): void {
        if (action.confirm && armed !== action.name) {
            armed = action.name;
            return;
        }
        ShellState.close();
        Quickshell.execDetached(action.command);
    }
    onVisibleChanged: {
        card = "";
        armed = "";
    }
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // A cream card pinned to the wall above the shelf.
    component Pinned: Rectangle {
        id: pinned
        default property alias contents: inside.data
        property real pad: 22 * shelf.u
        y: -height - 18 * shelf.u
        height: inside.childrenRect.height + 2 * pad
        color: Theme.card
        Rectangle {
            z: -1
            x: 4 * shelf.u
            y: 10 * shelf.u
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        MouseArea {
            anchors.fill: parent
            z: -1
        }
        Item {
            id: inside
            x: pinned.pad
            y: pinned.pad
            width: parent.width - 2 * pinned.pad
        }
    }

    // A round brass push with a word under it.
    component Push: Item {
        id: push
        property string word: ""
        property string glyph: ""
        property string icon: ""
        property bool red: false
        property bool down: false
        signal pressed(var event)
        width: 74 * shelf.u
        height: 84 * shelf.u
        Rectangle {
            id: knob
            anchors.horizontalCenter: parent.horizontalCenter
            y: push.down ? 3 * shelf.u : 0
            width: 50 * shelf.u
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: push.red ? "#f6b3a6" : (touch.containsMouse ? "#fff6d2" : "#f6e3a4")
                }
                GradientStop {
                    position: 0.55
                    color: push.red ? "#b3382c" : "#c9a04a"
                }
                GradientStop {
                    position: 1
                    color: push.red ? "#5e1712" : "#7a5612"
                }
            }
            border {
                width: 1
                color: push.red ? "#4a1410" : "#5a3d0e"
            }
            IconImage {
                anchors.centerIn: parent
                implicitSize: 26 * shelf.u
                visible: push.icon.length > 0
                source: push.icon
            }
            Glyph {
                anchors.centerIn: parent
                visible: push.icon.length === 0 && push.glyph.length > 0
                width: 24 * shelf.u
                height: width
                name: push.glyph
                color: push.red ? "#fff0ea" : "#2b1c05"
            }
        }
        Text {
            anchors {
                top: knob.bottom
                topMargin: 8 * shelf.u
                horizontalCenter: parent.horizontalCenter
            }
            width: parent.width + 8 * shelf.u
            horizontalAlignment: Text.AlignHCenter
            text: push.word
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: push.red ? Theme.red : Qt.alpha(Theme.fg, 0.8)
            font {
                family: Theme.sans
                pixelSize: 12 * shelf.u
                capitalization: Font.AllUppercase
                letterSpacing: 1.5 * shelf.u
            }
        }
        MouseArea {
            id: touch
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => push.pressed(event)
        }
    }

    // The clock.
    Item {
        id: dial
        y: 56 * shelf.u
        width: 132 * shelf.u
        height: width
        Rectangle {
            x: 3 * shelf.u
            y: 10 * shelf.u
            width: parent.width
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.5)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#f3d98c"
                }
                GradientStop {
                    position: 1
                    color: "#8f6a22"
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 9 * shelf.u
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#fbf6ea"
                }
                GradientStop {
                    position: 1
                    color: "#e0d7c4"
                }
            }
            border {
                width: 1
                color: "#6a4a14"
            }
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    x: parent.width / 2 - width / 2
                    y: 5 * shelf.u
                    width: (index % 3 === 0 ? 3 : 1.5) * shelf.u
                    height: (index % 3 === 0 ? 10 : 6) * shelf.u
                    color: Theme.ink
                    transform: Rotation {
                        origin.x: width / 2
                        origin.y: parent.height / 2 - 5 * shelf.u
                        angle: index * 30
                    }
                }
            }
            Rectangle {
                x: parent.width / 2 - width / 2
                y: parent.height / 2 - height
                width: 5 * shelf.u
                height: parent.height * 0.27
                radius: width / 2
                color: Theme.ink
                transformOrigin: Item.Bottom
                rotation: (clock.date.getHours() % 12) * 30 + clock.date.getMinutes() * 0.5
            }
            Rectangle {
                x: parent.width / 2 - width / 2
                y: parent.height / 2 - height
                width: 3 * shelf.u
                height: parent.height * 0.4
                color: Theme.ink
                transformOrigin: Item.Bottom
                rotation: clock.date.getMinutes() * 6
            }
            Rectangle {
                anchors.centerIn: parent
                width: 10 * shelf.u
                height: width
                radius: width / 2
                color: Theme.seal
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: shelf.pin("calendar")
        }
    }
    Column {
        anchors {
            left: dial.right
            leftMargin: 26 * shelf.u
            verticalCenter: dial.verticalCenter
        }
        spacing: 2 * shelf.u
        Text {
            text: Qt.formatDateTime(clock.date, "HH : mm")
            color: "#f1e1b0"
            font {
                family: Theme.serif
                pixelSize: 44 * shelf.u
                weight: Font.DemiBold
                letterSpacing: 2 * shelf.u
            }
        }
        Text {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM") + " · week " + RailLogic.isoWeek(clock.date)
            color: Qt.alpha(Theme.fg, 0.8)
            font {
                family: Theme.sans
                pixelSize: 19 * shelf.u
            }
        }
        Text {
            text: Logic.moonName(shelf.phase).toLowerCase() + ", " + Math.round((1 - Math.cos(shelf.phase * 2 * Math.PI)) * 50) + "% lit"
            color: Qt.alpha(Theme.fg, 0.55)
            font {
                family: Theme.serif
                pixelSize: 18 * shelf.u
                italic: true
            }
        }
    }

    // What is playing, on a card of its own.
    Rectangle {
        id: playing
        visible: shelf.player !== null
        anchors.horizontalCenter: parent.horizontalCenter
        y: 66 * shelf.u
        width: 560 * shelf.u
        height: 112 * shelf.u
        color: Theme.card
        Rectangle {
            z: -1
            x: 4 * shelf.u
            y: 10 * shelf.u
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        MouseArea {
            anchors.fill: parent
        }
        Rectangle {
            id: sleeve
            x: 16 * shelf.u
            anchors.verticalCenter: parent.verticalCenter
            width: 80 * shelf.u
            height: width
            color: Theme.ink
            Glyph {
                anchors.centerIn: parent
                width: 34 * shelf.u
                height: width
                name: "music"
                color: Theme.card
            }
            Image {
                anchors.fill: parent
                source: shelf.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }
        Column {
            anchors {
                left: sleeve.right
                leftMargin: 18 * shelf.u
                right: controls.left
                rightMargin: 12 * shelf.u
                verticalCenter: parent.verticalCenter
            }
            spacing: 1 * shelf.u
            Text {
                text: shelf.player?.isPlaying ? "Now playing" : "Paused"
                color: Theme.seal
                font {
                    family: Theme.sans
                    pixelSize: 13 * shelf.u
                    capitalization: Font.AllUppercase
                    letterSpacing: 3 * shelf.u
                }
            }
            Text {
                width: parent.width
                text: shelf.player?.trackTitle || shelf.player?.identity || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.ink
                font {
                    family: Theme.sans
                    pixelSize: 23 * shelf.u
                    weight: Font.Medium
                }
            }
            Text {
                width: parent.width
                text: shelf.player?.trackArtist || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.inkDim
                font {
                    family: Theme.serif
                    pixelSize: 20 * shelf.u
                    italic: true
                }
            }
        }
        Row {
            id: controls
            anchors {
                right: parent.right
                rightMargin: 18 * shelf.u
                verticalCenter: parent.verticalCenter
            }
            spacing: 8 * shelf.u
            Repeater {
                model: [
                    {
                        glyph: "previous",
                        act: () => shelf.player?.previous()
                    },
                    {
                        glyph: "toggle",
                        act: () => shelf.player?.togglePlaying()
                    },
                    {
                        glyph: "next",
                        act: () => shelf.player?.next()
                    }
                ]
                Rectangle {
                    id: control
                    required property var modelData
                    readonly property bool main: modelData.glyph === "toggle"
                    anchors.verticalCenter: parent.verticalCenter
                    width: (main ? 48 : 36) * shelf.u
                    height: width
                    radius: width / 2
                    color: main ? Theme.ink : (controlMouse.containsMouse ? Qt.alpha(Theme.ink, 0.12) : "transparent")
                    border {
                        width: 1
                        color: Theme.ink
                    }
                    Glyph {
                        anchors.centerIn: parent
                        width: (control.main ? 20 : 16) * shelf.u
                        height: width
                        name: control.main ? (shelf.player?.isPlaying ? "pause" : "play") : control.modelData.glyph
                        filled: true
                        weight: 1
                        color: control.main ? Theme.card : Theme.ink
                    }
                    MouseArea {
                        id: controlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: control.modelData.act()
                    }
                }
            }
        }
    }

    // The pushes: one per tray application, then volume, quiet, and the lights.
    Row {
        id: pushes
        anchors.right: parent.right
        y: 70 * shelf.u
        spacing: 4 * shelf.u
        Repeater {
            model: SystemTray.items
            Push {
                id: trayPush
                required property var modelData
                word: RailLogic.trayName(modelData)
                icon: modelData.icon
                glyph: "sparkle"
                down: shelf.card === "menu" && shelf.menuItem === modelData
                onPressed: event => {
                    if (event.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                    } else if (event.button === Qt.LeftButton && !modelData.onlyMenu) {
                        modelData.activate();
                        ShellState.close();
                    } else if (modelData.hasMenu) {
                        const again = shelf.card === "menu" && shelf.menuItem === modelData;
                        shelf.menuItem = modelData;
                        shelf.menuX = trayPush.mapToItem(shelf, trayPush.width / 2, 0).x;
                        menu.trail = [];
                        shelf.card = again ? "" : "menu";
                    }
                }
            }
        }
        Push {
            word: shelf.audio?.muted ? "muted" : "sound " + Math.round((shelf.audio?.volume ?? 0) * 100)
            glyph: shelf.audio?.muted ? "volume-off" : "volume"
            down: !!shelf.audio?.muted
            onPressed: event => {
                if (event.button === Qt.RightButton || event.button === Qt.MiddleButton)
                    Quickshell.execDetached(["pavucontrol"]);
                else if (shelf.audio)
                    shelf.audio.muted = !shelf.audio.muted;
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: event => {
                    if (shelf.audio)
                        shelf.audio.volume = Math.max(0, Math.min(1.5, shelf.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)));
                }
            }
        }
        Push {
            word: Notices.quiet ? "quiet" : "alerts"
            glyph: Notices.quiet ? "bell-off" : "bell"
            down: Notices.quiet
            onPressed: Notices.quiet = !Notices.quiet
        }
        Push {
            id: lightsPush
            word: "lights"
            glyph: "power"
            red: true
            down: shelf.card === "lights"
            onPressed: shelf.pin("lights")
        }
    }

    // The lights: what closing the room can mean.
    Pinned {
        visible: shelf.card === "lights"
        x: parent.width - width
        width: 300 * shelf.u
        Column {
            width: parent.width
            Text {
                bottomPadding: 8 * shelf.u
                text: shelf.armed.length > 0 ? "Press again to confirm" : "Lights"
                color: Theme.seal
                font {
                    family: Theme.sans
                    pixelSize: 13 * shelf.u
                    capitalization: Font.AllUppercase
                    letterSpacing: 3 * shelf.u
                }
            }
            Repeater {
                model: shelf.lights
                Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool armed: shelf.armed === modelData.name
                    width: parent.width + 16 * shelf.u
                    x: -8 * shelf.u
                    height: 40 * shelf.u
                    color: armed ? Theme.seal : (optionMouse.containsMouse ? Theme.ink : "transparent")
                    Text {
                        x: 8 * shelf.u
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.label
                        color: option.armed || optionMouse.containsMouse ? Theme.card : Theme.ink
                        font {
                            family: Theme.sans
                            pixelSize: 20 * shelf.u
                        }
                    }
                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shelf.press(option.modelData)
                    }
                }
            }
        }
    }

    // A tray application's own menu. A submenu replaces the list.
    Pinned {
        id: menu
        property var trail: []
        readonly property var openers: [rootMenu, firstSubmenu, secondSubmenu, thirdSubmenu]
        readonly property var listing: openers[trail.length].children
        readonly property bool gone: shelf.menuItem !== null && !SystemTray.items.values.includes(shelf.menuItem)
        visible: shelf.card === "menu"
        x: Math.max(0, Math.min(parent.width - width, shelf.menuX - width / 2))
        width: 360 * shelf.u
        pad: 14 * shelf.u
        onGoneChanged: {
            if (gone)
                shelf.card = "";
        }
        // A submenu only exists while its parent stays open, so each level keeps its own opener.
        QsMenuOpener {
            id: rootMenu
            menu: shelf.card === "menu" && shelf.menuItem ? shelf.menuItem.menu : null
        }
        QsMenuOpener {
            id: firstSubmenu
            menu: menu.trail[0] ?? null
        }
        QsMenuOpener {
            id: secondSubmenu
            menu: menu.trail[1] ?? null
        }
        QsMenuOpener {
            id: thirdSubmenu
            menu: menu.trail[2] ?? null
        }
        component Line: Item {
            id: line
            property string label: ""
            property bool rule: false
            property bool available: true
            property bool ticked: false
            property bool more: false
            signal chosen
            width: parent.width
            height: (rule ? 11 : 34) * shelf.u
            Rectangle {
                visible: line.rule
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Qt.alpha(Theme.ink, 0.35)
            }
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -6 * shelf.u
                anchors.rightMargin: -6 * shelf.u
                visible: !line.rule && line.available && lineMouse.containsMouse
                color: Theme.ink
            }
            Text {
                visible: !line.rule
                anchors {
                    left: parent.left
                    right: parent.right
                    rightMargin: 20 * shelf.u
                    verticalCenter: parent.verticalCenter
                }
                // Menus mark keyboard mnemonics with a single underscore.
                text: (line.ticked ? "✓  " : "") + line.label.replace(/_(?!_)/g, "").replace(/__/g, "_")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: !line.available ? Qt.alpha(Theme.ink, 0.4) : (lineMouse.containsMouse ? Theme.card : Theme.ink)
                font {
                    family: Theme.sans
                    pixelSize: 17 * shelf.u
                }
            }
            Text {
                visible: line.more
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: "›"
                color: lineMouse.containsMouse ? Theme.card : Theme.ink
                font {
                    family: Theme.sans
                    pixelSize: 19 * shelf.u
                }
            }
            MouseArea {
                id: lineMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !line.rule && line.available
                cursorShape: Qt.PointingHandCursor
                onClicked: line.chosen()
            }
        }
        Column {
            width: parent.width
            Line {
                visible: menu.trail.length > 0
                label: "‹ back"
                onChosen: menu.trail = menu.trail.slice(0, -1)
            }
            Repeater {
                model: menu.listing
                Line {
                    required property var modelData
                    required property int index
                    // Applications often end a menu with a rule.
                    visible: !(modelData.isSeparator && index === menu.listing.values.length - 1)
                    rule: modelData.isSeparator
                    label: modelData.text
                    available: modelData.enabled
                    ticked: modelData.buttonType !== QsMenuButtonType.None && modelData.checkState !== Qt.Unchecked
                    more: modelData.hasChildren && menu.trail.length < 3
                    onChosen: {
                        if (more) {
                            menu.trail = menu.trail.concat([modelData]);
                        } else {
                            modelData.triggered();
                            ShellState.close();
                        }
                    }
                }
            }
            Text {
                visible: menu.listing.values.length === 0
                text: "nothing to choose"
                color: Theme.inkDim
                font {
                    family: Theme.serif
                    pixelSize: 17 * shelf.u
                    italic: true
                }
            }
        }
    }

    // The month, with its weeks numbered.
    Pinned {
        visible: shelf.card === "calendar"
        readonly property real cell: 42 * shelf.u
        readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
        id: almanac
        width: cell * 8 + 2 * pad
        Column {
            width: parent.width
            spacing: 6 * shelf.u
            Item {
                width: parent.width
                height: 34 * shelf.u
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(shelf.month, "MMMM yyyy")
                    color: Theme.ink
                    font {
                        family: Theme.serif
                        pixelSize: 26 * shelf.u
                        weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shelf.month = new Date()
                    }
                }
                Row {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 18 * shelf.u
                    Repeater {
                        model: [-1, 1]
                        Text {
                            id: turn
                            required property int modelData
                            text: modelData < 0 ? "‹" : "›"
                            color: Theme.seal
                            font {
                                family: Theme.sans
                                pixelSize: 26 * shelf.u
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8 * shelf.u
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shelf.month = new Date(shelf.month.getFullYear(), shelf.month.getMonth() + turn.modelData, 1)
                            }
                        }
                    }
                }
            }
            Row {
                Repeater {
                    model: 8
                    Text {
                        required property int index
                        width: almanac.cell
                        horizontalAlignment: Text.AlignHCenter
                        // Dates are written in English; only the first weekday follows the locale.
                        text: index === 0 ? "wk" : Qt.locale("C").dayName((almanac.firstDay + index - 1) % 7, Locale.ShortFormat).slice(0, 2)
                        color: index === 0 ? Theme.inkDim : Theme.seal
                        font {
                            family: Theme.sans
                            pixelSize: 12 * shelf.u
                            capitalization: Font.AllUppercase
                            letterSpacing: 2 * shelf.u
                        }
                    }
                }
            }
            Column {
                Repeater {
                    model: RailLogic.monthWeeks(shelf.month.getFullYear(), shelf.month.getMonth(), almanac.firstDay, clock.date)
                    Row {
                        id: week
                        required property var modelData
                        Text {
                            width: almanac.cell
                            height: almanac.cell * 0.8
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: week.modelData.week
                            color: Theme.inkDim
                            font {
                                family: Theme.serif
                                pixelSize: 16 * shelf.u
                                italic: true
                            }
                        }
                        Repeater {
                            model: week.modelData.days
                            Item {
                                id: day
                                required property var modelData
                                width: almanac.cell
                                height: almanac.cell * 0.8
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: day.modelData.today
                                    width: 32 * shelf.u
                                    height: width
                                    radius: width / 2
                                    color: Theme.seal
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: day.modelData.day
                                    color: day.modelData.today ? Theme.card : (day.modelData.inMonth ? Theme.ink : Qt.alpha(Theme.ink, 0.35))
                                    font {
                                        family: Theme.sans
                                        pixelSize: 18 * shelf.u
                                        weight: day.modelData.today ? Font.DemiBold : Font.Normal
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            onWheel: event => shelf.month = new Date(shelf.month.getFullYear(), shelf.month.getMonth() + (event.angleDelta.y > 0 ? -1 : 1), 1)
        }
    }
}
