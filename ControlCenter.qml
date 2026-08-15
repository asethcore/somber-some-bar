import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    signal wifiMenuRequested()
    signal bluetoothMenuRequested()

    property int batteryPct: -1
    property bool batteryCharging: false
    property int volume: 0
    property bool volumeMuted: false
    property string dateText: ""

    property real brightness: -1
    property bool brightnessAvailable: false

    readonly property color panelColor: "#000000"
    readonly property color moduleColor: "#1c1c1e"
    readonly property color moduleHover: "#232326"
    readonly property color trackColor: "#2c2c2e"
    readonly property color textPrimary: "#f5f5f7"
    readonly property color textMuted: "#9b9da4"
    readonly property color textSecondary: "#8e8e93"
    readonly property color accent: "#0a84ff"
    readonly property color success: "#34c759"
    readonly property color switchOff: "#63656c"
    readonly property string wifiGlyph: "\uf1eb"
    readonly property string bluetoothGlyph: "\udb80\udcaf"
    readonly property string chargingGlyph: "\uf0e7"
    readonly property string brightnessGlyph: "\uf185"
    readonly property string volumeGlyph: "\uf028"

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d
        }
        return null
    }
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string wifiStatusText: {
        if (!Networking.wifiEnabled) return "Off"
        if (root.wifiDevice == null) return "Not Connected"
        if (root.wifiDevice.connected) {
            for (const n of root.wifiDevice.networks.values) {
                if (n.connected && n.name && n.name.length > 0) return n.name
            }
            return "Connected"
        }
        return "Not Connected"
    }

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: root.bluetoothAdapter != null && root.bluetoothAdapter.enabled
    readonly property string bluetoothStatusText: {
        const a = root.bluetoothAdapter
        if (a == null) return "Unavailable"
        if (!a.enabled) return "Off"
        for (const d of Bluetooth.devices.values) {
            if (d.connected) {
                const n = d.name || d.deviceName || ""
                if (n.length > 0) return n
                break
            }
        }
        return "On"
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function toggleBluetooth() {
        if (root.bluetoothAdapter != null)
            root.bluetoothAdapter.enabled = !root.bluetoothAdapter.enabled
    }

    function setVolume(v) {
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(v) + "%"])
    }

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
    }

    function setBrightness(v) {
        const pct = Math.round(Math.max(0, Math.min(100, v)))
        Quickshell.execDetached([
            "sh", "-c",
            "if command -v brightnessctl >/dev/null 2>&1; then brightnessctl -n set " + pct + "%; "
            + "else m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1); "
            + "echo $((m * " + pct + " / 100)) > /sys/class/backlight/*/brightness 2>/dev/null; fi"
        ])
    }

    Process {
        id: brightReadProc
        command: ["sh", "-c", "b=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1); m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1); if [ -n \"$b\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ]; then echo $((b * 100 / m)); fi"]
        stdout: SplitParser {
            onRead: (line) => {
                const v = parseFloat(String(line).trim())
                if (!isNaN(v)) {
                    root.brightness = Math.max(0, Math.min(100, Math.round(v)))
                    root.brightnessAvailable = true
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!brightReadProc.running) brightReadProc.running = true
        }
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Item {
            width: parent.width
            height: 28

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateText
                color: root.textSecondary
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.chargingGlyph
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                    visible: root.batteryCharging
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryPct >= 0 ? root.batteryPct + "%" : "--%"
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.family: "JetBrainsMono Nerd Font"
                    font.weight: Font.DemiBold
                }

                Item {
                    width: 28
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: 2
                        radius: 4
                        color: "transparent"
                        border.color: root.textSecondary
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            radius: 2
                            width: Math.max(0, (parent.width - 4) * (root.batteryPct / 100.0))
                            color: {
                                if (root.batteryPct <= 10) return "#FF3B30"
                                if (root.batteryPct <= 20) return "#FFCC00"
                                return "#34C759"
                            }

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Rectangle {
                        width: 2
                        height: 6
                        radius: 1
                        color: root.textSecondary
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 80

            Row {
                id: cardsRow
                anchors.fill: parent
                spacing: 12

                Rectangle {
                    id: wifiCard
                    width: (cardsRow.width - cardsRow.spacing) / 2
                    height: cardsRow.height
                    radius: 20
                    color: root.moduleColor

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        text: root.wifiGlyph
                        color: root.wifiEnabled ? root.accent : "#878a92"
                        font.pixelSize: 18
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Rectangle {
                        id: wifiSwitchTrack
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 34
                        height: 20
                        radius: 10
                        color: root.wifiEnabled ? root.success : root.switchOff

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: root.wifiEnabled ? 16 : 2
                            color: "#FFFFFF"

                            Behavior on x {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleWifi()
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: chevron.left
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            text: "Wi-Fi"
                            color: root.textPrimary
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: chevron.left
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            text: root.wifiStatusText
                            color: root.textMuted
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            id: chevron
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u203a"
                            color: "#8f9198"
                            font.pixelSize: 17
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.wifiMenuRequested()
                        }
                    }
                }

                Rectangle {
                    id: bluetoothCard
                    width: (cardsRow.width - cardsRow.spacing) / 2
                    height: cardsRow.height
                    radius: 20
                    color: root.moduleColor

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        text: root.bluetoothGlyph
                        color: root.bluetoothEnabled ? root.accent : "#878a92"
                        font.pixelSize: 18
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Rectangle {
                        id: bluetoothSwitchTrack
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 34
                        height: 20
                        radius: 10
                        color: root.bluetoothEnabled ? root.success : root.switchOff

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: root.bluetoothEnabled ? 16 : 2
                            color: "#FFFFFF"

                            Behavior on x {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleBluetooth()
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: bluetoothChevron.left
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            text: "Bluetooth"
                            color: root.textPrimary
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: bluetoothChevron.left
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            text: root.bluetoothStatusText
                            color: root.textMuted
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            id: bluetoothChevron
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u203a"
                            color: "#8f9198"
                            font.pixelSize: 17
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bluetoothMenuRequested()
                        }
                    }
                }
            }
        }

        ControlSliderCard {
            width: parent.width
            height: 76
            title: "Display"
            iconText: root.brightnessGlyph
            value: root.brightnessAvailable ? root.brightness / 100 : 0
            enabled: root.brightnessAvailable
            onValueMoved: (v) => root.setBrightness(v * 100)
        }

        ControlSliderCard {
            width: parent.width
            height: 76
            title: "Sound"
            iconText: root.volumeMuted ? "\uf026" : root.volumeGlyph
            value: root.volume / 100
            onValueMoved: (v) => root.setVolume(v * 100)
        }
    }

    component ControlSliderCard: Rectangle {
        id: sliderRoot

        signal valueMoved(real value)

        property string title: ""
        property string iconText: ""
        property real value: 0
        property bool enabled: true

        radius: 24
        color: root.moduleColor
        clip: true

        opacity: enabled ? 1.0 : 0.5
        Behavior on opacity { NumberAnimation { duration: 200 } }

        function clamp01(nextValue) {
            return Math.max(0, Math.min(1, nextValue))
        }

        Item {
            anchors.fill: parent
            anchors.margins: 12

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                text: sliderRoot.title
                color: root.textPrimary
                font.pixelSize: 13
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: sliderTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22
                radius: 11
                color: "#1d1f24"
                border.width: 1
                border.color: "#30333a"
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: sliderRoot.iconText
                        color: root.textSecondary
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                Rectangle {
                    width: sliderRoot.value <= 0.001
                        ? 0
                        : Math.max(34, Math.min(sliderTrack.width, sliderTrack.width * sliderRoot.value + 1))
                    height: parent.height
                    radius: parent.radius
                    color: "#eceef2"
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * sliderRoot.value - width / 2))
                    y: -1
                    width: 24
                    height: 24
                    radius: 12
                    border.width: 1
                    border.color: "#b8ffffff"
                    color: "#f4f5f7"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: sliderRoot.enabled
                    hoverEnabled: true

                    function update(mouseX) {
                        sliderRoot.valueMoved(sliderRoot.clamp01(mouseX / width))
                    }

                    onPressed: (mouse) => update(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) update(mouse.x) }
                }
            }
        }
    }
}
