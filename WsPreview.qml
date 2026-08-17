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
                    && c.mapped && !c.hidden) {
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

    property var iconIndex: ({})

    function iconPrio(p, ext) {
        let pr = 50
        if (p.indexOf("/128x128/") !== -1) pr = 100
        else if (p.indexOf("/128x128@2/") !== -1) pr = 95
        else if (p.indexOf("/256x256/") !== -1) pr = 80
        else if (p.indexOf("/512x512/") !== -1) pr = 70
        if (ext === "png") pr += 5
        return pr
    }

    function buildIconIndex(text) {
        const map = {}
        const lines = String(text).split("\n")
        for (const line of lines) {
            const p = line.trim()
            if (p.length < 5 || p.charAt(0) !== "/") continue
            const slash = p.lastIndexOf("/")
            const file = p.slice(slash + 1)
            const dot = file.lastIndexOf(".")
            if (dot <= 0) continue
            const base = file.slice(0, dot)
            const ext = file.slice(dot + 1)
            if (ext !== "png" && ext !== "svg") continue
            if (!map[base]) map[base] = []
            map[base].push({ path: p, prio: root.iconPrio(p, ext) })
        }
        for (const k in map) {
            map[k].sort((a, b) => b.prio - a.prio)
        }
        root.iconIndex = map
    }

    function iconPath(cls) {
        if (!cls) return ""
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
            const entries = root.iconIndex[c]
            if (entries && entries.length > 0) return "file://" + entries[0].path
        }
        return ""
    }

    Process {
        id: iconScan
        command: ["sh", "-c", "find /run/current-system/sw/share/icons/hicolor -mindepth 3 -maxdepth 3 \\( -type f -o -type l \\) \\( -iname '*.png' -o -iname '*.svg' \\) ! -path '*/symbolic/*' 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.buildIconIndex(this.text)
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
