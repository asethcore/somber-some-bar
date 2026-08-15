import QtQuick

Item {
    id: root

    property int selectedHours: 0
    property int selectedMinutes: 5
    property int totalSeconds: 300
    property int remainingSeconds: 0
    property bool running: false
    property bool active: false
    property real animatedProgress: 0

    readonly property int displaySeconds: root.active ? root.remainingSeconds : 0
    readonly property real targetProgress: root.active && root.totalSeconds > 0
        ? Math.max(0, Math.min(1, root.remainingSeconds / root.totalSeconds))
        : 0
    readonly property bool canStart: root.inputTotalSeconds() > 0 && (!root.active || root.remainingSeconds > 0)
    readonly property string startLabel: root.running
        ? "Stop"
        : (root.active && root.remainingSeconds > 0 && root.remainingSeconds < root.totalSeconds ? "Continue" : "Start")
    readonly property string timeText: {
        const s = Math.max(0, root.displaySeconds)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = s % 60
        const mm = m < 10 ? "0" + m : "" + m
        const ss = sec < 10 ? "0" + sec : "" + sec
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.running
        onTriggered: {
            root.remainingSeconds -= 1
            if (root.remainingSeconds <= 0) {
                root.remainingSeconds = 0
                root.running = false
                root.active = false
            }
        }
    }

    Behavior on animatedProgress {
        NumberAnimation {
            duration: 700
            easing.type: Easing.InOutCubic
        }
    }

    onTargetProgressChanged: root.animatedProgress = root.targetProgress
    onAnimatedProgressChanged: progressRing.requestPaint()

    function clampInt(value, minValue, maxValue) {
        const parsed = parseInt(value, 10)
        if (isNaN(parsed)) return minValue
        return Math.max(minValue, Math.min(maxValue, parsed))
    }

    function inputHours() {
        return root.clampInt(hourInput.text, 0, 23)
    }

    function inputMinutes() {
        return root.clampInt(minuteInput.text, 0, 59)
    }

    function inputTotalSeconds() {
        return root.inputHours() * 3600 + root.inputMinutes() * 60
    }

    function normalizeInputs() {
        hourInput.text = "" + root.selectedHours
        minuteInput.text = root.selectedMinutes < 10 ? "0" + root.selectedMinutes : "" + root.selectedMinutes
    }

    function toggleTimer() {
        if (!root.active || !root.running) {
            root.totalSeconds = root.inputTotalSeconds()
            root.remainingSeconds = root.totalSeconds
            root.active = true
            root.running = true
        } else {
            root.running = false
        }
    }

    function resetTimer() {
        root.active = false
        root.running = false
        root.remainingSeconds = 0
        root.normalizeInputs()
    }

    onSelectedHoursChanged: root.normalizeInputs()
    onSelectedMinutesChanged: root.normalizeInputs()
    Component.onCompleted: root.normalizeInputs()

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 18

        Item {
            width: 104
            height: parent.height

            Canvas {
                id: progressRing

                anchors.centerIn: parent
                width: 104
                height: 104

                onPaint: {
                    const ctx = getContext("2d")
                    const cx = width / 2
                    const cy = height / 2
                    const lw = 5
                    const radius = Math.min(width, height) / 2 - lw / 2
                    const startAngle = -Math.PI / 2
                    const progress = Math.max(0, Math.min(1, root.animatedProgress))
                    const endAngle = startAngle - Math.PI * 2 * progress

                    ctx.clearRect(0, 0, width, height)
                    ctx.lineCap = "round"
                    ctx.lineWidth = lw

                    ctx.beginPath()
                    ctx.strokeStyle = "#2b2e35"
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                    ctx.stroke()

                    if (progress > 0) {
                        ctx.beginPath()
                        ctx.strokeStyle = root.running ? "#ff9f0a" : "#8a6d1f"
                        ctx.arc(cx, cy, radius, startAngle, endAngle, true)
                        ctx.stroke()
                    }
                }
            }

            Text {
                anchors.centerIn: progressRing
                text: root.timeText
                color: "#FFFFFF"
                font.pixelSize: root.displaySeconds >= 3600 ? 15 : 19
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Column {
            width: parent.width - 122
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Row {
                width: parent.width
                height: 42
                spacing: 8

                TimerInput {
                    id: hourInput

                    width: (parent.width - 8) / 2
                    height: parent.height
                    label: "h"
                }

                TimerInput {
                    id: minuteInput

                    width: (parent.width - 8) / 2
                    height: parent.height
                    label: "m"
                    onEditingFinished: {
                        root.normalizeInputs()
                    }
                }
            }

            Row {
                width: parent.width
                height: 34
                spacing: 8

                TimerButton {
                    width: (parent.width - 8) / 2
                    height: parent.height
                    label: root.startLabel
                    enabled: root.running || root.canStart
                    accent: true
                    onClicked: root.toggleTimer()
                }

                TimerButton {
                    width: (parent.width - 8) / 2
                    height: parent.height
                    label: "Reset"
                    onClicked: root.resetTimer()
                }
            }
        }
    }

    component TimerInput: Item {
        id: inputRoot

        signal editingFinished()

        property alias text: input.text
        property string label: ""

        function grabKeyboardFocus() {
            input.forceActiveFocus()
            input.selectAll()
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: input.activeFocus ? "#26262a" : (inputMouse.containsMouse ? "#232327" : "#1c1c20")
            border.width: 1
            border.color: input.activeFocus ? "#ff9f0a" : "#2b2e35"
        }

        MouseArea {
            id: inputMouse

            anchors.fill: parent
            z: 2
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            onPressed: (mouse) => {
                inputRoot.grabKeyboardFocus()
                mouse.accepted = true
            }
            onClicked: (mouse) => {
                mouse.accepted = true
            }
        }

        Row {
            z: 1
            anchors.centerIn: parent
            spacing: 4

            TextInput {
                id: input

                width: 42
                property bool sanitizing: false
                color: "#f5f5f7"
                selectionColor: "#ff9f0a"
                selectedTextColor: "#111111"
                font.pixelSize: 15
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.DemiBold
                horizontalAlignment: TextInput.AlignRight
                validator: IntValidator {
                    bottom: 0
                    top: 99
                }
                inputMethodHints: Qt.ImhDigitsOnly
                cursorVisible: activeFocus
                onTextChanged: {
                    if (sanitizing) return
                    const digits = text.replace(/[^0-9]/g, "").slice(0, 2)
                    if (digits !== text) {
                        sanitizing = true
                        text = digits
                        sanitizing = false
                    }
                }
                onEditingFinished: inputRoot.editingFinished()
                Keys.onReturnPressed: inputRoot.editingFinished()
                Keys.onEnterPressed: inputRoot.editingFinished()
            }

            Text {
                text: inputRoot.label
                color: "#9b9da4"
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Medium
            }
        }
    }

    component TimerButton: Item {
        id: buttonRoot

        signal clicked()

        property string label: ""
        property bool accent: false
        property bool enabled: true

        opacity: enabled ? 1.0 : 0.45
        scale: buttonArea.pressed ? 0.96 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: buttonRoot.accent
                ? (buttonArea.pressed ? "#d98500" : "#ff9f0a")
                : (buttonArea.pressed ? "#232327" : "#1c1c20")
            border.width: 1
            border.color: buttonRoot.accent ? "#ff9f0a" : "#2b2e35"
        }

        Text {
            anchors.centerIn: parent
            text: buttonRoot.label
            color: buttonRoot.accent ? "#111111" : "#f5f5f7"
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            enabled: buttonRoot.enabled
            preventStealing: true
            onClicked: buttonRoot.clicked()
        }
    }
}
