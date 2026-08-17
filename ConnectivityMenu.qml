import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

Item {
    id: root
    width: 440
    height: root.panelHeight
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.open ? root.openY : root.closedY
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    layer.enabled: true
    layer.effect: Shadow {}

    readonly property real openY: root.parent ? root.parent.height - root.panelHeight : 0
    readonly property real closedY: root.parent ? root.parent.height + 4 : 1084

    property bool open: false
    property int mode: 0
    property real topR: 16
    property real earR: 16
    property real rowH: 52
    property real rowSpacing: 4

    readonly property bool isWifi: root.mode === 0
    readonly property bool isBluetooth: root.mode === 1

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d
        }
        return null
    }
    readonly property var wifiNetworks: root.wifiDevice ? root.wifiDevice.networks : null

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDevices: root.bluetoothAdapter ? root.bluetoothAdapter.devices : null

    property string pendingSsid: ""
    property string pendingPassword: ""
    property string statusText: ""

    readonly property var earOut: root.earR * 2.75
    readonly property var earDown: root.earR * 0.9

    readonly property real panelHeight: 12 + 40 + 12 + (root.pendingSsid.length > 0 ? 92 + 12 : 0) + root.listHeight() + 12

    ScriptModel {
        id: wifiModel
        objectProp: "name"
    }

    Timer {
        id: wifiRefreshTimer
        interval: 2000
        repeat: true
        running: root.isWifi && root.open
        onTriggered: root.refreshWifi()
    }

    function refreshWifi() {
        const list = root.sortedWifi()
        if (root.isWifi) wifiModel.values = list
    }

    function sortedWifi() {
        const out = []
        if (!root.wifiNetworks) return out
        for (const n of root.wifiNetworks.values) out.push(n)
        out.sort((a, b) => {
            if (!!a.connected !== !!b.connected) return a.connected ? -1 : 1
            return (b.signalStrength || 0) - (a.signalStrength || 0)
        })
        return out
    }

    function btDevices(section) {
        const out = []
        if (!root.bluetoothDevices) return out
        for (const d of root.bluetoothDevices.values) {
            const paired = d.paired || d.bonded
            if (section === 0 && d.connected) out.push(d)
            else if (section === 1 && !d.connected && paired) out.push(d)
            else if (section === 2 && !paired) out.push(d)
        }
        return out
    }

    function btName(d) {
        return d.deviceName && d.deviceName.length > 0 ? d.deviceName : (d.name || "Unknown device")
    }

    function btSubtitle(d) {
        const parts = []
        if (d.connected) parts.push("Connected")
        else if (d.pairing) parts.push("Pairing")
        else if (d.paired || d.bonded) parts.push("Paired")
        else parts.push("Available")
        if (d.batteryAvailable) parts.push(Math.round(d.battery) + "%")
        return parts.join("  \u00b7  ")
    }

    function wifiTitle(n) {
        return n.name && n.name.length > 0 ? n.name : "(Hidden network)"
    }

    function wifiSubtitle(n) {
        if (n.connected) return "Connected"
        if (n.stateChanging) return "Connecting..."
        if (n.security === WifiSecurityType.Open) return "Open network"
        if (n.known) return "Secure network"
        return "Secure network - click to connect"
    }

    function wifiSignalText(n) {
        const s = Math.round((n.signalStrength || 0) * 100)
        return s + "%"
    }

    function wifiIcon(n) {
        return "\uf1eb"
    }

    function wifiIsSecure(n) {
        return n.security !== WifiSecurityType.Open
    }

    function connectWifi(n) {
        if (n.connected) return
        if (root.pendingSsid.length > 0) return
        if (n.security !== WifiSecurityType.Open && !n.known) {
            root.pendingSsid = n.name || ""
            root.pendingPassword = ""
            root.statusText = ""
            return
        }
        root.statusText = ""
        n.connect()
    }

    function submitWifiPassword() {
        if (root.pendingSsid.length === 0) return
        if (root.pendingPassword.length === 0) {
            root.statusText = "Enter a password first"
            return
        }
        const ssid = root.pendingSsid
        const psk = root.pendingPassword
        root.pendingSsid = ""
        root.pendingPassword = ""
        root.statusText = ""
        const list = root.sortedWifi()
        for (const n of list) {
            if ((n.name || "") === ssid) {
                n.connectWithPsk(psk)
                return
            }
        }
    }

    function handleBt(d) {
        const addr = d.address || ""
        if (addr.length === 0) return
        if (d.connected) {
            btProcess.running = false
            btProcess.command = ["bluetoothctl", "disconnect", addr]
            btProcess.running = true
        } else if (d.paired || d.bonded) {
            btProcess.running = false
            btProcess.command = ["bluetoothctl", "connect", addr]
            btProcess.running = true
        } else {
            btProcess.running = false
            btProcess.command = ["sh", "-c", "bluetoothctl --timeout 15 pair " + addr + " && bluetoothctl connect " + addr]
            btProcess.running = true
        }
    }

    Process {
        id: btProcess
        running: false
    }

    function reset() {
        root.pendingSsid = ""
        root.pendingPassword = ""
        root.statusText = ""
    }

    onOpenChanged: {
        if (root.open) {
            root.statusText = ""
            root.pendingSsid = ""
            root.pendingPassword = ""
            if (root.isWifi) {
                if (root.wifiDevice != null) root.wifiDevice.scannerEnabled = true
                root.refreshWifi()
            } else if (root.bluetoothAdapter != null) {
                root.bluetoothAdapter.discovering = true
            }
            focusTimer.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 90
        onTriggered: root.forceActiveFocus()
    }

    Keys.onEscapePressed: root.open = false

    Shape {
        x: -root.earOut
        y: 0
        width: root.width + root.earOut * 2
        height: root.height + root.earDown
        antialiasing: true
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true

        ShapePath {
            fillColor: "#110F0A"
            strokeColor: "#322C24"
            strokeWidth: 1
            fillRule: ShapePath.WindingFill

            readonly property real left: root.earOut
            readonly property real right: root.earOut + root.width
            readonly property real bottom: root.height

            startX: left
            startY: root.topR

            PathCubic {
                x: root.earOut + root.topR; y: 0
                control1X: root.earOut; control1Y: root.topR * 0.5
                control2X: root.earOut + root.topR * 0.5; control2Y: 0
            }

            PathLine { x: root.earOut + root.width - root.topR; y: 0 }

            PathCubic {
                x: root.earOut + root.width; y: root.topR
                control1X: root.earOut + root.width - root.topR * 0.5; control1Y: 0
                control2X: root.earOut + root.width; control2Y: root.topR * 0.5
            }

            PathLine { x: root.earOut + root.width; y: root.height - root.earR }

            PathCubic {
                x: root.earOut + root.width - root.earR; y: root.height
                control1X: root.earOut + root.width; control1Y: root.height + root.earR * 0.8
                control2X: root.earOut + root.width + root.earR * 2.5; control2Y: root.height
            }

            PathLine { x: root.earOut + root.earR; y: root.height }

            PathCubic {
                x: root.earOut; y: root.height - root.earR
                control1X: root.earOut - root.earR * 2.5; control1Y: root.height
                control2X: root.earOut; control2Y: root.height + root.earR * 0.8
            }

            PathLine { x: root.earOut; y: root.topR }
        }
    }

    Item {
        id: content
        anchors.fill: parent
        clip: true

        Column {
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: 12

            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isWifi ? "Wi-Fi" : "Bluetooth"
                    color: "#FFFFFF"
                    font.pixelSize: 15
                    font.bold: true
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isWifi
                            ? "\uf1eb"
                            : (root.bluetoothAdapter != null && root.bluetoothAdapter.enabled ? "\udb80\udcaf" : "\udb80\udcb2")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: root.isWifi ? (Networking.wifiEnabled ? "#5E86E0" : "#656057")
                            : (root.bluetoothAdapter != null && root.bluetoothAdapter.enabled ? "#5E86E0" : "#656057")
                    }

                    Rectangle {
                        id: toggleTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 20
                        radius: 10
                        color: root.isWifi ? (Networking.wifiEnabled ? "#34C759" : "#63656C")
                            : (root.bluetoothAdapter != null && root.bluetoothAdapter.enabled ? "#34C759" : "#63656C")

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: root.isWifi ? (Networking.wifiEnabled ? 16 : 2)
                                : (root.bluetoothAdapter != null && root.bluetoothAdapter.enabled ? 16 : 2)
                            color: "#FFFFFF"

                            Behavior on x {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.isWifi) {
                                    Networking.wifiEnabled = !Networking.wifiEnabled
                                    if (Networking.wifiEnabled && root.wifiDevice != null) root.wifiDevice.scannerEnabled = true
                                } else if (root.bluetoothAdapter != null) {
                                    root.bluetoothAdapter.enabled = !root.bluetoothAdapter.enabled
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 92
                radius: 12
                color: "#1c1c20"
                visible: root.isWifi && root.pendingSsid.length > 0
                border.width: 1
                border.color: "#2b2e35"

                onVisibleChanged: {
                    if (visible) pskField.forceActiveFocus()
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        width: parent.width
                        text: "Password for " + root.pendingSsid
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - 50 - 8 - 46 - 8
                            height: 34
                            radius: 10
                            color: "#212226"
                            border.width: 1
                            border.color: "#3f4046"

                            TextInput {
                                id: pskField
                                anchors.fill: parent
                                anchors.margins: 10
                                color: "#FFFFFF"
                                font.pixelSize: 13
                                clip: true
                                echoMode: TextInput.Password
                                text: root.pendingPassword
                                onTextChanged: root.pendingPassword = text
                                Keys.onReturnPressed: root.submitWifiPassword()
                            }
                        }

                        Rectangle {
                            id: joinButton
                            width: 46
                            height: 34
                            radius: 10
                            color: "#5E86E0"

                            Text {
                                anchors.centerIn: parent
                                text: "Join"
                                color: "#FFFFFF"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.submitWifiPassword()
                            }
                        }

                        Rectangle {
                            width: 50
                            height: 34
                            radius: 10
                            color: "#4a4b50"

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: "#FFFFFF"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.pendingSsid = ""
                                    root.pendingPassword = ""
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: root.listHeight()
                clip: true

                Flickable {
                    id: networkList
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: networkColumn.implicitHeight

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 6
                        background: Rectangle { color: "transparent" }
                        contentItem: Rectangle {
                            radius: 3
                            color: "#3A352C"
                        }
                    }

                    Column {
                        id: networkColumn
                        width: networkList.width
                        spacing: root.rowSpacing

                    Repeater {
                        model: root.isWifi ? wifiModel : []

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: root.rowH
                            radius: 12
                            color: rowMouse.containsMouse ? "#2B261E" : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.wifiIcon(modelData)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 15
                                        color: modelData.connected ? "#5E86E0" : "#959187"
                                    }

                                    Text {
                                        anchors.top: parent.top
                                        anchors.topMargin: -3
                                        anchors.right: parent.right
                                        anchors.rightMargin: -3
                                        text: "\uf033e"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 8
                                        color: "#959187"
                                        visible: root.wifiIsSecure(modelData)
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: root.wifiTitle(modelData)
                                        color: "#FFFFFF"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: parent.parent.parent.width - 120
                                    }

                                    Text {
                                        text: root.wifiSubtitle(modelData)
                                        color: "#959187"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        width: parent.parent.parent.width - 120
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: root.wifiSignalText(modelData)
                                    color: "#f0f0f3"
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: "\uf00c"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: "#34C759"
                                    visible: modelData.connected
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectWifi(modelData)
                            }
                        }
                    }

                    Repeater {
                        model: root.isWifi ? [] : [0, 1, 2]

                        delegate: Item {
                            width: parent.width
                            height: root.btSectionCount(modelData) > 0 ? 22 + root.btSectionHeight(modelData) : 0
                            visible: height > 0

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                text: ["Connected", "Paired", "Available"][modelData]
                                color: "#959187"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Column {
                                anchors.top: parent.top
                                anchors.topMargin: 20
                                width: parent.width
                                spacing: root.rowSpacing

                                Repeater {
                                    model: root.btDevices(modelData)

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: root.rowH
                                        radius: 12
                                        color: btMouse.containsMouse ? "#2B261E" : "transparent"

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 12

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.connected ? "\udb80\udcaf" : "\udb80\udcb2"
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 15
                                                color: modelData.connected ? "#5E86E0" : "#959187"
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Text {
                                                    text: root.btName(modelData)
                                                    color: "#FFFFFF"
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                    width: parent.parent.parent.width - 110
                                                }

                                                Text {
                                                    text: root.btSubtitle(modelData)
                                                    color: "#959187"
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                    width: parent.parent.parent.width - 110
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "\uf00c"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: "#34C759"
                                            visible: modelData.connected
                                        }

                                        MouseArea {
                                            id: btMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.handleBt(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: root.statusText.length > 0
                        text: root.statusText
                        color: "#ff7c72"
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                    }

                    Text {
                        width: parent.width
                        visible: root.isWifi && root.sortedWifi().length === 0 && Networking.wifiEnabled
                        text: "No networks found. Scanning..."
                        color: "#959187"
                        font.pixelSize: 12
                    }

                    Text {
                        width: parent.width
                        visible: root.isBluetooth && root.bluetoothDevices && root.btDevices(0).length === 0 && root.btDevices(1).length === 0 && root.btDevices(2).length === 0
                        text: "No devices found. Scanning..."
                        color: "#959187"
                        font.pixelSize: 12
                    }
                }
                }
            }
        }
    }

    function btSectionCount(section) {
        return root.btDevices(section).length
    }

    function btSectionHeight(section) {
        const n = root.btDevices(section).length
        if (n === 0) return 0
        return n * root.rowH + (n - 1) * root.rowSpacing
    }

    readonly property real maxListH: 340

    function contentHeight() {
        if (root.isWifi) {
            const list = root.sortedWifi()
            let h = Math.max(1, list.length) * root.rowH + Math.max(0, list.length - 1) * root.rowSpacing
            if (root.statusText.length > 0) h += 16 + root.rowSpacing
            if (list.length === 0) h = 52
            return h
        }
        let h = 52
        for (let i = 0; i < 3; i++) {
            const n = root.btDevices(i).length
            if (n > 0) h += 22 + n * root.rowH + (n - 1) * root.rowSpacing + root.rowSpacing
        }
        return h
    }

    function listHeight() {
        return Math.min(root.maxListH, Math.max(52, root.contentHeight()))
    }
}
