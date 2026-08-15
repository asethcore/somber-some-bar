import Quickshell.Io
import QtQuick

Item {
    id: root

    property string wallpaperDir: "/home/seth/Pictures/walls"
    property string wallpaperConfig: "/home/seth/.config/hypr/hyprpaper.conf"
    property string monitor: ""
    property string activePath: ""
    property bool loaded: false

    ListModel {
        id: wallpapers
    }

    Process {
        id: currentProcess
        command: [
            "bash", "-c",
            "PATH=\"$HOME/.nix-profile/bin:$PATH\" awww query | grep -oE 'image: .*' | head -1"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                const m = /image: (.+)$/.exec(String(line).trim())
                if (m) root.activePath = m[1].trim()
            }
        }
        onExited: if (root.loaded) root.syncActiveIndex()
    }

    Process {
        id: monitorProcess
        command: ["hyprctl", "monitors", "-j"]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const monitors = JSON.parse(String(line))
                    if (Array.isArray(monitors) && monitors.length > 0) {
                        root.monitor = monitors[0].name
                        root.startScan()
                    }
                } catch (e) {
                    root.startScan()
                }
            }
        }
        onExited: if (root.monitor === "") root.startScan()
    }

    function startScan() {
        if (scanProcess.running) scanProcess.running = false
        if (currentProcess.running) currentProcess.running = false
        wallpapers.clear()
        root.loaded = false
        currentProcess.running = true
        scanProcess.running = true
    }

    Process {
        id: scanProcess
        command: [
            "bash", "-c",
            "find '" + root.wallpaperDir + "' -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.gif' \\) 2>/dev/null | sort"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                const p = String(line).trim()
                if (p !== "" && p.indexOf("file://") !== 0)
                    root.addWallpaper(p)
            }
        }
        onExited: {
            root.loaded = true
            root.syncActiveIndex()
        }
    }

    Process {
        id: applyProcess
        property string applyPath: ""
        command: ["/home/seth/.local/bin/wallpaper-apply", applyProcess.applyPath]
        onExited: root.activePath = applyProcess.applyPath
    }

    function addWallpaper(path) {
        wallpapers.append({ filePath: path, fileName: path.split("/").pop() })
    }

    function syncActiveIndex() {
        if (root.activePath === "") return
        for (let i = 0; i < wallpapers.count; i++) {
            if (wallpapers.get(i).filePath === root.activePath) {
                pathView.currentIndex = i
                return
            }
        }
    }

    function applyWallpaper(path) {
        if (path === "") return
        applyProcess.applyPath = path
        if (applyProcess.running) applyProcess.running = false
        applyProcess.running = true
    }

    Component.onCompleted: {
        if (monitorProcess.running) monitorProcess.running = false
        monitorProcess.running = true
    }

    readonly property real topPad: 12
    readonly property real botPad: 8
    readonly property real hPad: 12
    readonly property real headerH: 30
    readonly property real headerGap: 6

    readonly property real slotW: (width - hPad * 2) / 3
    readonly property real cardW: Math.round(slotW * 1.45)
    readonly property real cardH: Math.round(cardW * 0.6)
    readonly property real spacing: slotW * 1.6
    readonly property real sideScale: 0.78

    readonly property real cardAreaH: height - topPad - headerH - headerGap - botPad
    readonly property real cardPathY: cardAreaH / 2

    Column {
        anchors.fill: parent
        anchors.topMargin: root.topPad
        anchors.leftMargin: root.hPad
        anchors.rightMargin: root.hPad
        anchors.bottomMargin: root.botPad
        spacing: root.headerGap

        Item {
            width: parent.width
            height: root.headerH

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf03e  Wallpapers"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: "#FFFFFF"
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: wallpapers.count + " in ~/Pictures/walls"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: "#8e8e93"
            }
        }

        Item {
            width: parent.width
            height: root.cardAreaH
            clip: true

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: !root.loaded || wallpapers.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.loaded ? "\uf03e" : "Scanning\u2026"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.loaded ? 26 : 12
                    color: Qt.rgba(1, 1, 1, 0.25)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.loaded && wallpapers.count === 0
                    text: "No wallpapers found\nin ~/Pictures/walls"
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    lineHeight: 1.5
                }
            }

            PathView {
                id: pathView
                anchors.fill: parent
                model: root.loaded ? wallpapers : null
                clip: false

                pathItemCount: Math.min(wallpapers.count, 3)
                cacheItemCount: 4
                snapMode: PathView.SnapToItem
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 200

                path: Path {
                    startX: pathView.width / 2 - root.spacing
                    startY: root.cardPathY
                    PathLine {
                        x: pathView.width / 2 + root.spacing
                        y: root.cardPathY
                    }
                }

                delegate: Item {
                    readonly property bool isCurrent: PathView.isCurrentItem
                    readonly property bool onPath: PathView.onPath

                    width: root.cardW
                    height: root.cardH + 6 + 18
                    z: isCurrent ? 3 : 1

                    property real sc: isCurrent ? 1.18 : (onPath ? 0.72 : 0.0)
                    Behavior on sc {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    property real op: isCurrent ? 1.0 : (onPath ? 0.65 : 0.0)
                    Behavior on op {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Item {
                        id: inner
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: root.cardW
                        height: root.cardH + 6 + 18
                        scale: sc
                        opacity: op
                        transformOrigin: Item.Center

                        Rectangle {
                            id: thumb
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cardW
                            height: root.cardH
                            radius: 12
                            color: "#1a1a1a"
                            clip: false
                            border.width: model.filePath === root.activePath ? 2.5 : 0
                            border.color: "#5E86E0"
                            layer.enabled: true
                            layer.effect: Shadow {
                                shadowEnabled: true
                                shadowBlur: 0.8
                                shadowVerticalOffset: 4
                                shadowOpacity: 0.5
                            }

                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                source: "file://" + encodeURI(model.filePath)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                mipmap: true
                                sourceSize: Qt.size(480, 300)
                                visible: thumbImg.status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "#282828"
                                opacity: thumbImg.status === Image.Ready ? 0 : 1
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.top: thumb.bottom
                            anchors.topMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cardW - 4
                            text: model.fileName
                            color: isCurrent ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: isCurrent ? 10 : 9
                            font.family: "JetBrainsMono Nerd Font"
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }

                        MouseArea {
                            anchors.fill: thumb
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isCurrent)
                                    root.applyWallpaper(model.filePath)
                                else
                                    pathView.currentIndex = index
                            }
                        }
                    }
                }
            }
        }
    }
}
