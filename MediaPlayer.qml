import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root

    property var activePlayer: null
    property real position: 0
    property real length: 0

    readonly property bool isPlaying: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property real progress: root.length > 0 ? Math.min(1, Math.max(0, root.position / root.length)) : 0
    readonly property string trackTitle: root.activePlayer ? root.activePlayer.trackTitle : ""
    readonly property string trackArtist: root.activePlayer ? root.activePlayer.trackArtist : ""
    readonly property string artUrl: root.activePlayer ? (root.activePlayer.trackArtUrl || "") : ""
    readonly property string trackUrl: root.activePlayer ? String(root.activePlayer.metadata["xesam:url"] || "") : ""

    property real vizPhase: 0

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0
        sec = Math.floor(sec)
        const m = Math.floor(sec / 60)
        const s = sec % 60
        return ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2)
    }

    function vizLevel(i) {
        const p = root.vizPhase + i * 0.78
        const a = (Math.sin(p) + 1) * 0.5
        const b = (Math.sin(p * 2 + i * 0.95) + 1) * 0.5
        return 0.22 + a * 0.42 + b * 0.24
    }

    function pausedVizLevel(i) {
        return ([0.34, 0.58, 0.82, 0.58, 0.34][i] || 0.4)
    }

    function togglePlayback() {
        if (!root.activePlayer || !root.activePlayer.canControl) return
        if (root.activePlayer.canTogglePlaying) {
            root.activePlayer.togglePlaying()
            return
        }
        if (root.activePlayer.playbackState === MprisPlaybackState.Playing) {
            if (root.activePlayer.canPause) root.activePlayer.pause()
            return
        }
        if (root.activePlayer.canPlay) root.activePlayer.play()
    }

    Timer {
        interval: 64
        repeat: true
        running: root.isPlaying
        onTriggered: {
            root.vizPhase += 0.18
            if (root.vizPhase > Math.PI * 2) root.vizPhase -= Math.PI * 2
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Item {
            width: parent.width
            height: 60

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                CoverArt {
                    width: 60
                    height: 60
                    radius: 14
                    artUrl: root.artUrl
                    trackUrl: root.trackUrl
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: root.trackTitle ? root.trackTitle : "No media is playing"
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                        font.weight: Font.DemiBold
                        width: 190
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.trackArtist
                        color: "#8e8e93"
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        font.weight: Font.Medium
                        width: 200
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 22

                Row {
                    anchors.centerIn: parent
                    height: parent.height
                    spacing: 4

                    Repeater {
                        model: 5

                        delegate: Rectangle {
                            width: 4
                            height: root.isPlaying
                                ? 6 + (parent.height - 6) * root.vizLevel(index)
                                : 6 + (parent.height - 6) * root.pausedVizLevel(index)
                            radius: 2
                            color: root.isPlaying ? "#b56cff" : "#5f4b72"
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on height {
                                NumberAnimation {
                                    duration: root.isPlaying ? 120 : 260
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: root.isPlaying ? 140 : 280
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 14

            Text {
                id: timeL
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmtTime(root.position)
                color: "#8e8e93"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: timeL.right
                anchors.right: timeR.left
                anchors.margins: 10
                height: 5
                radius: 3
                color: "#333333"

                Rectangle {
                    height: parent.height
                    radius: 3
                    color: "#FFFFFF"
                    width: parent.width * root.progress

                    Behavior on width {
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                id: timeR
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmtTime(root.length)
                color: "#8e8e93"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Medium
            }
        }

        Item {
            width: parent.width
            height: 32

            Row {
                anchors.centerIn: parent
                spacing: 50

                Item {
                    width: 28
                    height: 28
                    scale: prevArea.pressed ? 0.8 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }

                    Canvas {
                        anchors.fill: parent
                        property color fillColor: prevArea.pressed ? "#888" : "#FFFFFF"
                        onFillColorChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = fillColor
                            ctx.strokeStyle = fillColor
                            ctx.lineJoin = "round"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.rect(3, 5, 3, 18)
                            ctx.moveTo(14, 5)
                            ctx.lineTo(6, 14)
                            ctx.lineTo(14, 23)
                            ctx.closePath()
                            ctx.moveTo(23, 5)
                            ctx.lineTo(15, 14)
                            ctx.lineTo(23, 23)
                            ctx.closePath()
                            ctx.fill()
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        anchors.margins: -15
                        preventStealing: true
                        onClicked: if (root.activePlayer) root.activePlayer.previous()
                    }
                }

                Item {
                    width: 28
                    height: 28
                    scale: playArea.pressed ? 0.8 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: root.isPlaying

                        Rectangle { width: 6; height: 20; radius: 2; color: playArea.pressed ? "#888" : "#FFFFFF" }
                        Rectangle { width: 6; height: 20; radius: 2; color: playArea.pressed ? "#888" : "#FFFFFF" }
                    }

                    Canvas {
                        anchors.fill: parent
                        visible: !root.isPlaying
                        property color fillColor: playArea.pressed ? "#888" : "#FFFFFF"
                        onFillColorChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = fillColor
                            ctx.strokeStyle = fillColor
                            ctx.lineJoin = "round"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(8, 4)
                            ctx.lineTo(24, 14)
                            ctx.lineTo(8, 24)
                            ctx.closePath()
                            ctx.fill()
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        anchors.margins: -15
                        preventStealing: true
                        onClicked: root.togglePlayback()
                    }
                }

                Item {
                    width: 28
                    height: 28
                    scale: nextArea.pressed ? 0.8 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }

                    Canvas {
                        anchors.fill: parent
                        property color fillColor: nextArea.pressed ? "#888" : "#FFFFFF"
                        onFillColorChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = fillColor
                            ctx.strokeStyle = fillColor
                            ctx.lineJoin = "round"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(5, 5)
                            ctx.lineTo(13, 14)
                            ctx.lineTo(5, 23)
                            ctx.closePath()
                            ctx.moveTo(14, 5)
                            ctx.lineTo(22, 14)
                            ctx.lineTo(14, 23)
                            ctx.closePath()
                            ctx.rect(22, 5, 3, 18)
                            ctx.fill()
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        anchors.margins: -15
                        preventStealing: true
                        onClicked: if (root.activePlayer) root.activePlayer.next()
                    }
                }
            }
        }
    }
}
