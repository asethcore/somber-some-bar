import Quickshell.Io
import QtQuick
import Quickshell.Widgets

Item {
    id: root

    property int wsId: 0
    property var clients: []
    property int iconSize: 20
    property int cornerRadius: 4
    property color windowColor: "#433A2F"
    property color windowBorder: "#0B0906"

    readonly property var tiled: {
        const out = []
        for (const c of root.clients) {
            if (c.workspace && c.workspace.id === root.wsId
                    && c.mapped && !c.hidden && !c.floating) {
                out.push(c)
            }
        }
        return out
    }

    readonly property var bounds: {
        let minX = Infinity
        let minY = Infinity
        let maxX = -Infinity
        let maxY = -Infinity
        for (const c of root.tiled) {
            minX = Math.min(minX, c.at[0])
            minY = Math.min(minY, c.at[1])
            maxX = Math.max(maxX, c.at[0] + c.size[0])
            maxY = Math.max(maxY, c.at[1] + c.size[1])
        }
        if (!isFinite(minX)) return null
        return { x: minX, y: minY, w: maxX - minX, h: maxY - minY }
    }

    readonly property real scaleX: root.bounds ? root.width / root.bounds.w : 1
    readonly property real scaleY: root.bounds ? root.height / root.bounds.h : 1

    readonly property var iconSet: {
        const s = new Set()
        for (const n of root.iconNames) s.add(n)
        return s
    }

    property var iconNames: []

    function iconPath(cls) {
        if (!cls) return ""
        const base = "/run/current-system/sw/share/icons/hicolor/128x128/apps/"
        const candidates = []
        const known = {
            "Spotify": "spotify-client",
            "spotify": "spotify-client"
        }
        if (known[cls]) candidates.push(known[cls])
        candidates.push(cls)
        candidates.push(cls.toLowerCase())
        candidates.push(cls.replace(/\./g, "-").toLowerCase())
        const seen = {}
        for (const c of candidates) {
            if (!c || seen[c]) continue
            seen[c] = true
            if (root.iconSet.has(c)) return "file://" + base + c + ".png"
        }
        return ""
    }

    Process {
        id: iconScan
        command: ["sh", "-c", "ls /run/current-system/sw/share/icons/hicolor/128x128/apps/ 2>/dev/null | sed 's/\\.png$//'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const names = []
                const lines = String(this.text).split("\n")
                for (const line of lines) {
                    const n = line.trim()
                    if (n !== "") names.push(n)
                }
                root.iconNames = names
            }
        }
    }

    Repeater {
        model: root.tiled

        Rectangle {
            required property var modelData

            x: (modelData.at[0] - root.bounds.x) * root.scaleX
            y: (modelData.at[1] - root.bounds.y) * root.scaleY
            width: Math.max(2, modelData.size[0] * root.scaleX)
            height: Math.max(2, modelData.size[1] * root.scaleY)
            radius: root.cornerRadius
            color: root.windowColor
            border.width: 1
            border.color: root.windowBorder
            clip: true

            IconImage {
                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize
                visible: parent.width >= root.iconSize + 10 && parent.height >= root.iconSize + 10
                source: root.iconPath(modelData.class)
            }
        }
    }
}
