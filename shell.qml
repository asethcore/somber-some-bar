import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

PanelWindow {
    id: root
    color: "transparent"
    WlrLayershell.namespace: "qs_bar"
    WlrLayershell.keyboardFocus: (appDrawer.open || connectivityMenu.open || root.expand > 0.5) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    anchors { left: true; right: true; top: true }
    implicitHeight: root.screen ? root.screen.height : 1080
    exclusiveZone: 48

    mask: Region {
        item: centerPill
        Region { item: searchPill }
        Region { item: wsPill }
        Region { item: sysPill }
        Region { item: timePill }
        Region { item: appDrawer }
        Region { item: connectivityMenu }
    }

    property real expand: 0

    onExpandChanged: {
        if (root.expand > 0.5) escapeCatcher.forceActiveFocus()
    }

    function closeAllPopups() {
        if (connectivityMenu.open) {
            connectivityMenu.open = false
        } else if (appDrawer.open) {
            appDrawer.open = false
        } else if (root.expand > 0.5) {
            root.expand = 0
            root.expandView = 0
        }
    }

    Item {
        id: escapeCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeAllPopups()
    }

    Behavior on expand {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    property real pillW: root.pillTargetW()
    property real pillH: root.pillTargetH()
    Behavior on pillW { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on pillH { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    readonly property int wsBoxW: 160
    readonly property int wsBoxH: 92
    readonly property int wsCols: 5
    readonly property int wsSpacing: 12
    readonly property int wsPadH: 56
    readonly property int wsPadV: 24

    readonly property int mediaW: 480
    readonly property int mediaH: 160

    readonly property var activePlayer: {
        let best = null
        let bestScore = -1
        for (const p of Mpris.players.values) {
            if (!p.isPlaying) continue
            let score = 0
            if (p.trackTitle) score += 1
            if (p.trackArtUrl) score += 2
            const u = String(p.metadata["xesam:url"] || "")
            if (/youtu\.?be|vimeo|i\.scdn\.co|music\.apple/i.test(u)) score += 1
            if (score > bestScore) {
                bestScore = score
                best = p
            }
        }
        return best
    }
    readonly property bool mediaActive: root.activePlayer != null
    property int expandView: 0
    readonly property int viewCount: 4
    readonly property bool showMedia: root.expandView === 1
    readonly property real mediaLen: root.activePlayer ? root.activePlayer.length : 0
    property real mediaPos: 0
    readonly property real mediaProgress: root.mediaLen > 0 ? Math.min(1, root.mediaPos / root.mediaLen) : 0

    function waveH(i) {
        const n = 48
        const x = i / (n - 1)
        const h = 0.5 + 0.5 * Math.sin(x * Math.PI * 5 + Math.sin(x * Math.PI * 1.5) * 2.5)
        return Math.round(4 + h * 16)
    }

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0
        sec = Math.floor(sec)
        const m = Math.floor(sec / 60)
        const s = sec % 60
        return ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2)
    }

    property bool wheelArmed: true

    Timer {
        id: wheelReset
        interval: 600
        onTriggered: root.wheelArmed = true
    }

    Timer {
        id: mediaTicker
        interval: 500
        repeat: true
        running: root.mediaActive
        onTriggered: root.mediaPos = root.activePlayer ? root.activePlayer.position : 0
    }

    readonly property var occupiedWs: {
        const apps = root.workspaceApps()
        const ids = []
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0 && (apps[ws.id] || []).length > 0) {
                ids.push(ws.id)
            }
        }
        ids.sort((a, b) => a - b)
        return ids
    }

    readonly property real collapsedW: 320

    readonly property int timerW: 360
    readonly property int timerH: 180
    readonly property int wallW: 480
    readonly property int wallH: 288
    readonly property int notifW: 380
    readonly property int notifH: 300
    readonly property int ccW: 460
    readonly property int ccH: 336

    function expandWidth() {
        switch (root.expandView) {
            case 1: return root.mediaW
            case 2: return root.timerW
            case 3: return root.wallW
            case 4: return root.notifW
            case 5: return root.ccW
        }
        const n = root.occupiedWs.length
        if (n === 0) return 216
        const cols = Math.min(n, root.wsCols)
        return cols * root.wsBoxW + (cols - 1) * root.wsSpacing + root.wsPadH
    }

    function expandHeight() {
        switch (root.expandView) {
            case 1: return root.mediaH
            case 2: return root.timerH
            case 3: return root.wallH
            case 4: return root.notifH
            case 5: return root.ccH
        }
        const n = root.occupiedWs.length
        if (n === 0) return 50
        const rows = Math.ceil(n / root.wsCols)
        return rows * root.wsBoxH + (rows - 1) * root.wsSpacing + root.wsPadV
    }

    readonly property real notifPopupW: 400

    Item {
        id: notifProbes
        visible: false

        Text {
            id: summaryProbe
            width: 274
            wrapMode: Text.WordWrap
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            text: root.notifSummary
        }

        Text {
            id: bodyProbe
            width: 280
            wrapMode: Text.WordWrap
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            text: root.notifBody
        }
    }

    function notifPopupHeight() {
        const appH = 12
        const summaryH = summaryProbe.height
        const bodyH = (root.notifBody !== "" && root.notifSummary !== "") ? bodyProbe.height + 2 : 0
        const colH = appH + 2 + summaryH + 2 + bodyH
        const contentH = Math.max(26, colH)
        return Math.min(220, Math.max(64, 32 + contentH))
    }

    function pillTargetW() {
        if (root.notifVisible && root.expand < 0.5) return root.notifPopupW
        if ((root.volPopupVisible || root.brightPopupVisible) && root.expand < 0.5) return 330
        return root.expand > 0.5 ? root.expandWidth() : root.collapsedW
    }

    function pillTargetH() {
        if (root.notifVisible && root.expand < 0.5) return root.notifPopupHeight()
        if ((root.volPopupVisible || root.brightPopupVisible) && root.expand < 0.5) return 60
        return root.expand > 0.5 ? root.expandHeight() : 44
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property var wsList: {
        const ids = [1, 2, 3, 4, 5]
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 5) ids.push(ws.id)
        }
        ids.sort((a, b) => a - b)
        return ids
    }

    function wsExists(id) {
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id === id) return true
        }
        return false
    }

    function wsFocused(id) {
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id === id && ws.focused) return true
        }
        return false
    }

    readonly property string timeText: {
        const h = clock.hours
        const suffix = h >= 12 ? "PM" : "AM"
        let h12 = h % 12
        if (h12 === 0) h12 = 12
        return ("0" + h12).slice(-2) + ":" + ("0" + clock.minutes).slice(-2) + " " + suffix
    }

    readonly property string dateText: {
        const d = clock.date
        if (!d) return ""
        return Qt.formatDateTime(d, "ddd, MMM d")
    }

    readonly property var battery: UPower.displayDevice
    readonly property int pct: {
        if (battery == null) return 0
        const p = battery.percentage
        return Math.round(p <= 1 ? p * 100 : p)
    }
    readonly property string greenColor: "#8BC34A"
    readonly property string yellowColor: "#E5C07B"

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d
        }
        return null
    }
    readonly property bool wifiConnected: wifiDevice != null && wifiDevice.connected

    property int volBars: 3
    property real volPct: 0
    property bool volMuted: false

    property var clients: []

    function parseClients(text) {
        try {
            const arr = JSON.parse(text)
            root.clients = Array.isArray(arr) ? arr : []
        } catch (e) {
            root.clients = []
        }
    }

    function focusedWindows() {
        const ws = Hyprland.focusedWorkspace
        const wsId = ws ? ws.id : 0
        const out = []
        for (const c of root.clients) {
            if (c.workspace && c.workspace.id === wsId && c.mapped && !c.hidden) {
                out.push(c.title && c.title.length > 0 ? c.title : c.class)
            }
        }
        return out
    }

    function workspaceApps() {
        const map = {}
        for (const c of root.clients) {
            if (c.workspace && c.mapped && !c.hidden && c.workspace.id > 0) {
                if (!map[c.workspace.id]) map[c.workspace.id] = []
                if (c.class && map[c.workspace.id].indexOf(c.class) === -1) {
                    map[c.workspace.id].push(c.class)
                }
            }
        }
        return map
    }

    function occupiedWorkspaces() {
        return root.occupiedWs
    }

    Process {
        id: clientsProcess
        command: ["hyprctl", "clients", "-j"]
        running: true
        onRunningChanged: {
            if (!running) {
                clientsRestart.start()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.parseClients(this.text)
        }
    }

    Timer {
        id: clientsRestart
        interval: 2000
        onTriggered: clientsProcess.running = true
    }

    function parseVol(text) {
        const m = text.match(/Volume:\s*([0-9.]+)/)
        if (!m) return
        const muted = text.indexOf("MUTED") !== -1
        const v = Math.round(parseFloat(m[1]) * 100)
        root.volPct = v
        root.volMuted = muted
        if (muted || v <= 0) root.volBars = 0
        else if (v < 20) root.volBars = 1
        else if (v <= 50) root.volBars = 2
        else if (v < 75) root.volBars = 3
        else root.volBars = 4
    }

    property int brightPct: -1
    property bool brightAvailable: false

    function parseBright(text) {
        const v = parseFloat(text.trim())
        if (!isNaN(v)) {
            root.brightPct = Math.max(0, Math.min(100, Math.round(v)))
            root.brightAvailable = true
        }
    }

    Process {
        id: brightProcess
        command: ["sh", "-c", "b=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1); m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1); if [ -n \"$b\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ]; then echo $((b * 100 / m)); fi"]
        running: true
        onRunningChanged: {
            if (!running) {
                brightRestart.start()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.parseBright(this.text)
        }
    }

    Timer {
        id: brightRestart
        interval: 2000
        onTriggered: brightProcess.running = true
    }

    Process {
        id: volProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        onRunningChanged: {
            if (!running) {
                volRestart.start()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.parseVol(this.text)
        }
    }

    Timer {
        id: volRestart
        interval: 2000
        onTriggered: volProcess.running = true
    }

    Pill {
        id: centerPill
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.pillW
        height: root.pillH
        topRadius: 16
        bottomRadius: 16 - (2 * root.expand)
        inset: 14
        color: "#110F0A"

        Item {
            id: collapsedTitle
            anchors.fill: parent
            opacity: Math.max(0, 1 - root.expand * 2)
            visible: opacity > 0

            Text {
                anchors.centerIn: parent
                opacity: root.notifVisible || root.volPopupVisible || root.brightPopupVisible ? 0 : 1
                visible: opacity > 0
                width: parent.width - 96
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : "hyprland"
                color: "#FFFFFF"
                font.pixelSize: 14
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
            }

            Rectangle {
                id: notifBar
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                opacity: root.notifVisible ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                radius: 16
                color: "#110F0A"

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        width: 26
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "\uf0f3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 26
                        color: "#FFFFFF"
                    }

                    Column {
                        width: parent.width - 26 - 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.notifApp
                            elide: Text.ElideRight
                            color: "#8e8e93"
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                        }

                        Text {
                            width: parent.width
                            text: root.notifSummary !== "" ? root.notifSummary : root.notifBody
                            wrapMode: Text.WordWrap
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: root.notifBody !== "" && root.notifSummary !== ""
                            width: parent.width
                            text: root.notifBody
                            wrapMode: Text.WordWrap
                            color: "#b0b0b5"
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }
            }

            Item {
                id: volBar
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: (root.volPopupVisible && !root.notifVisible) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.volMuted ? "\uf026" : (root.volPct >= 50 ? "\uf028" : "\uf027")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: "#FFFFFF"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.volMuted ? "Muted" : root.volPct + "%"
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        height: 6
                        radius: 3
                        color: "#3A352C"

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.volPct / 100))
                            height: parent.height
                            radius: 3
                            color: "#5E86E0"

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            Item {
                id: brightBar
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: (root.brightPopupVisible && !root.notifVisible && !root.volPopupVisible) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf185"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: "#FFFFFF"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.brightPct >= 0 ? root.brightPct + "%" : "--%"
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        height: 6
                        radius: 3
                        color: "#3A352C"

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.brightPct / 100))
                            height: parent.height
                            radius: 3
                            color: "#5E86E0"

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: mediaBar
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                opacity: (root.showMedia && !root.notifVisible && !root.volPopupVisible && !root.brightPopupVisible) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                radius: height / 2
                color: "#2B261E"

                CoverArt {
                    width: 28
                    height: 28
                    radius: 14
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    artUrl: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
                    trackUrl: root.activePlayer ? String(root.activePlayer.metadata["xesam:url"] || "") : ""
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 120
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.activePlayer ? (root.activePlayer.trackTitle || "Now Playing") : "No media is playing"
                    color: "#FFFFFF"
                    font.pixelSize: 13
                }
            }
        }

        Item {
            id: expandedContent
            z: 1
            opacity: Math.max(0, root.expand * 2 - 1)
            visible: opacity > 0
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            anchors.bottomMargin: 12

            Item {
                id: workspaceView
                anchors.fill: parent
                opacity: root.expandView === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

                Flow {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    spacing: root.wsSpacing
                    width: {
                        const n = root.occupiedWs.length
                        const cols = Math.max(1, Math.min(n, root.wsCols))
                        return cols * root.wsBoxW + (cols - 1) * root.wsSpacing
                    }

                    Repeater {
                        model: root.occupiedWs

                        Rectangle {
                            width: root.wsBoxW
                            height: root.wsBoxH
                            radius: 10
                            color: "#2B261E"
                            border.width: root.wsFocused(modelData) ? 2 : 0
                            border.color: "#5E86E0"
                            clip: true

                            WsPreview {
                                anchors.fill: parent
                                anchors.margins: 5
                                wsId: modelData
                                clients: root.clients
                            }
                        }
                    }
                }
            }

        Item {
            id: mediaView
            anchors.fill: parent
            opacity: root.expandView === 1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            MediaPlayer {
                anchors.fill: parent
                activePlayer: root.activePlayer
                position: root.mediaPos
                length: root.mediaLen
            }
        }

        Item {
            id: timerView
            anchors.fill: parent
            opacity: root.expandView === 2 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            TimerPage {
                anchors.fill: parent
            }
        }

        Item {
            id: wallView
            anchors.fill: parent
            opacity: root.expandView === 3 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            WallpaperPicker {
                anchors.fill: parent
            }
        }

        Item {
            id: notifView
            anchors.fill: parent
            opacity: root.expandView === 4 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            NotificationCenter {
                anchors.fill: parent
                model: notificationHistory
            }
        }

        Item {
            id: ccView
            anchors.fill: parent
            opacity: root.expandView === 5 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            ControlCenter {
                id: controlCenterView
                anchors.fill: parent
                batteryPct: root.pct
                batteryCharging: root.battery != null && root.battery.state === 1
                volume: root.volPct
                volumeMuted: root.volMuted
                dateText: root.dateText
                onWifiMenuRequested: root.openConnectivityMenu(0)
                onBluetoothMenuRequested: root.openConnectivityMenu(1)
            }
        }
    }

        Timer {
            id: closeTimer
            interval: 120
            onTriggered: {
                root.expand = 0
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                closeTimer.stop()
                if (mouseY <= 44) {
                    root.expand = 1
                }
            }
            onPositionChanged: {
                closeTimer.stop()
                if (mouseY <= 44) {
                    root.expand = 1
                }
            }
            onExited: {
                if (root.expandView === 5 || root.expandView === 4) return
                closeTimer.start()
            }
            onWheel: (wheel) => {
                wheelReset.restart()
                if (Math.abs(root.expand - 1) > 0.01) return
                if (!root.wheelArmed) return
                root.wheelArmed = false
                if (root.expandView === 5 || root.expandView === 4) return
                root.expandView = (root.expandView + 1) % root.viewCount
            }
        }
    }

    Rectangle {
        id: searchPill
        anchors.top: parent.top
        anchors.topMargin: 7
        anchors.right: wsPill.left
        anchors.rightMargin: 14
        width: 30
        height: 30
        radius: 15
        color: "#110F0A"
        layer.enabled: true
        layer.effect: Shadow {}

        Text {
            anchors.centerIn: parent
            text: "\uf002"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: "#FFFFFF"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                connectivityMenu.open = false
                appDrawer.open = !appDrawer.open
            }
        }
    }

    Rectangle {
        id: wsPill
        anchors.top: parent.top
        anchors.topMargin: 7
        anchors.right: centerPill.left
        anchors.rightMargin: 0
        height: 30
        radius: 15
        color: "#110F0A"
        layer.enabled: true
        layer.effect: Shadow {}
        width: wsRow.width + 16

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.wsList

                Item {
                    width: 24
                    height: 24

                    Rectangle {
                        id: ring
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: "#FFFFFF"
                    }

                    Rectangle {
                        anchors.centerIn: ring
                        width: 10
                        height: 10
                        radius: 5
                        color: root.wsFocused(modelData) ? "#5E86E0" : "#FFFFFF"
                        visible: root.wsExists(modelData)
                    }
                }
            }
        }
    }

    Rectangle {
        id: sysPill
        anchors.top: parent.top
        anchors.topMargin: 7
        anchors.left: centerPill.right
        anchors.leftMargin: 0
        height: 30
        radius: 15
        color: "#110F0A"
        layer.enabled: true
        layer.effect: Shadow {}
        width: sysRow.width + 16

        Row {
            id: sysRow
            anchors.centerIn: parent
            spacing: 6

            Item {
                id: batteryItem
                width: 20
                height: 20
                visible: root.battery != null

                Shape {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    antialiasing: true
                    layer.enabled: true
                    layer.samples: 24

                    ShapePath {
                        strokeColor: root.pct > 50 ? root.greenColor : root.yellowColor
                        strokeWidth: 2.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathMove { x: 10; y: 1 }

                        PathAngleArc {
                            centerX: 10
                            centerY: 10
                            radiusX: 9
                            radiusY: 9
                            startAngle: 90
                            sweepAngle: -360 * root.pct / 100
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf0e7"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#FFFFFF"
                }
            }

            Item {
                id: notifItem
                width: 20
                height: 20

                Text {
                    anchors.centerIn: parent
                    text: "\uf0f3"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: "#FFFFFF"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        connectivityMenu.open = false
                        appDrawer.open = false
                        if (root.expand > 0.5 && root.expandView === 4) {
                            root.expand = 0
                            root.expandView = 0
                        } else {
                            root.expand = 1
                            root.expandView = 4
                        }
                    }
                }
            }

            Item {
                id: settingsItem
                width: 20
                height: 20

                Text {
                    anchors.centerIn: parent
                    text: "\uf013"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: "#FFFFFF"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        connectivityMenu.open = false
                        appDrawer.open = false
                        if (root.expand > 0.5 && root.expandView === 5) {
                            root.expand = 0
                            root.expandView = 0
                        } else {
                            root.expand = 1
                            root.expandView = 5
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: timePill
        anchors.top: parent.top
        anchors.topMargin: 7
        anchors.left: sysPill.right
        anchors.leftMargin: 14
        height: 30
        radius: 15
        color: "#110F0A"
        layer.enabled: true
        layer.effect: Shadow {}
        width: timeLabel.implicitWidth + 16

        Text {
            id: timeLabel
            anchors.centerIn: parent
            text: root.timeText
            color: "#FFFFFF"
            font.pixelSize: 13
        }
    }

    function openConnectivityMenu(mode) {
        root.expand = 0
        appDrawer.open = false
        connectivityMenu.mode = mode
        connectivityMenu.reset()
        connectivityMenu.open = !(connectivityMenu.open && connectivityMenu.mode === mode)
    }

    readonly property string socketPath: "/tmp/qs-bar.sock"
    property bool ipcReady: false

    SocketServer {
        id: ipc
        path: root.socketPath
        active: root.ipcReady

        handler: Socket {
            parser: SplitParser {
                onRead: (message) => {
                    const m = message.trim()
                    if (m === "toggle") {
                        connectivityMenu.open = false
                        appDrawer.open = !appDrawer.open
                    } else if (m === "volume") {
                        root.showVolPopup()
                    } else if (m === "brightness") {
                        root.showBrightPopup()
                    } else if (m.indexOf("view") === 0) {
                        const n = parseInt(m.slice(4), 10)
                        if (!isNaN(n) && n >= 0 && n <= 5) {
                            connectivityMenu.open = false
                            appDrawer.open = false
                            root.expandView = n
                            root.expand = 1
                        }
                    } else if (m === "collapse") {
                        root.expand = 0
                        root.expandView = 0
                    } else if (m === "wifi") {
                        root.expand = 0
                        appDrawer.open = false
                        connectivityMenu.mode = 0
                        connectivityMenu.reset()
                        connectivityMenu.open = true
                    } else if (m === "bluetooth") {
                        root.expand = 0
                        appDrawer.open = false
                        connectivityMenu.mode = 1
                        connectivityMenu.reset()
                        connectivityMenu.open = true
                    }
                }
            }
        }
    }

    Process {
        id: ipcCleanup
        command: ["rm", "-f", root.socketPath]
        running: true
        onRunningChanged: {
            if (!running) root.ipcReady = true
        }
    }

    AppDrawer {
        id: appDrawer
        anchors.horizontalCenter: parent.horizontalCenter
    }

    ConnectivityMenu {
        id: connectivityMenu
        anchors.horizontalCenter: parent.horizontalCenter
    }

    ListModel {
        id: notificationHistory
    }

    property string notifApp: ""
    property string notifSummary: ""
    property string notifBody: ""
    property bool notifVisible: false

    property bool volPopupVisible: false
    property bool brightPopupVisible: false

    function showVolPopup() {
        root.volPopupVisible = true
        volPopupHideTimer.restart()
        if (!volProcess.running) {
            volProcess.running = true
        }
        volRestart.stop()
        volRestart.start()
    }

    function showBrightPopup() {
        root.brightPopupVisible = true
        brightPopupHideTimer.restart()
        if (!brightProcess.running) {
            brightProcess.running = true
        }
        brightRestart.stop()
        brightRestart.start()
    }

    function pushNotification(appName, summary, body, ref) {
        notificationHistory.append({ appName: appName, summary: summary, body: body, ref: ref })
        while (notificationHistory.count > 30) notificationHistory.remove(0)
    }

    function removeNotification(ref) {
        for (let i = 0; i < notificationHistory.count; i++) {
            if (notificationHistory.get(i).ref === ref) {
                notificationHistory.remove(i)
                break
            }
        }
    }

    NotificationServer {
        id: notificationServer
        onNotification: (n) => {
            root.notifApp = n.appName
            root.notifSummary = n.summary
            root.notifBody = n.body
            root.notifVisible = true
            notifHideTimer.restart()
            root.pushNotification(n.appName, n.summary, n.body, n)
            n.closed.connect(() => root.removeNotification(n))
        }
    }

    Timer {
        id: notifHideTimer
        interval: 4000
        onTriggered: root.notifVisible = false
    }

    Timer {
        id: volPopupHideTimer
        interval: 1500
        onTriggered: root.volPopupVisible = false
    }

    Timer {
        id: brightPopupHideTimer
        interval: 1500
        onTriggered: root.brightPopupVisible = false
    }
}
