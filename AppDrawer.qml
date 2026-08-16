import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
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
    property real topR: 16
    property real earR: 16
    property real rowH: 56
    property real rowSpacing: 4

    property var fileResults: []
    property string lastSearch: ""

    readonly property real earOut: root.earR * 2.75
    readonly property real earDown: root.earR * 0.9

    readonly property real panelHeight: 12 + 40 + 12 + root.gridHeight() + 12

    onOpenChanged: {
        if (root.open) {
            focusTimer.start()
        } else {
            searchInput.text = ""
            root.fileResults = []
        }
    }

    Timer {
        id: focusTimer
        interval: 90
        onTriggered: {
            list.positionViewAtBeginning()
            searchInput.forceActiveFocus()
        }
    }

    Timer {
        id: searchDebounce
        interval: 400
        onTriggered: root.runFileSearch()
    }

    Process {
        id: fileSearchProcess
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseFiles(this.text)
        }
    }

    function runFileSearch() {
        const q = searchInput.text.trim()
        if (q.length < 2) {
            root.fileResults = []
            return
        }
        root.lastSearch = q
        fileSearchProcess.running = false
        fileSearchProcess.command = [
            "timeout", "3",
            "find", "/",
            "-maxdepth", "5",
            "-not", "-path", "/proc/*",
            "-not", "-path", "/sys/*",
            "-not", "-path", "/dev/*",
            "-not", "-path", "/nix/*",
            "-not", "-path", "/run/*",
            "-iname", "*" + q + "*",
            "-printf", "%y %p\n"
        ]
        fileSearchProcess.running = true
    }

    function parseFiles(text) {
        const out = []
        const lines = text.split("\n")
        for (const line of lines) {
            if (line.length < 3) continue
            const type = line.charAt(0)
            const path = line.substring(2)
            if (!path || path.charAt(0) !== "/") continue
            const name = path.substring(path.lastIndexOf("/") + 1)
            if (out.length >= 8) break
            out.push({ name: name, path: path, isDir: type === "d" })
        }
        root.fileResults = out
    }

    function evalMath(expr) {
        let i = 0
        const s = expr

        function skipWs() {
            while (i < s.length && (s[i] === ' ' || s[i] === '\t')) i++
        }
        function parseExpr() {
            let v = parseTerm()
            skipWs()
            while (i < s.length && (s[i] === '+' || s[i] === '-')) {
                const op = s[i]
                i++
                const rhs = parseTerm()
                if (op === '+') v += rhs
                else v -= rhs
                skipWs()
            }
            return v
        }
        function parseTerm() {
            let v = parseFactor()
            skipWs()
            while (i < s.length && (s[i] === '*' || s[i] === '/' || s[i] === '%')) {
                const op = s[i]
                i++
                const rhs = parseFactor()
                if (op === '*') v *= rhs
                else if (op === '/') {
                    if (rhs === 0) throw new Error("div0")
                    v /= rhs
                } else {
                    if (rhs === 0) throw new Error("mod0")
                    v %= rhs
                }
                skipWs()
            }
            return v
        }
        function parseFactor() {
            skipWs()
            if (i >= s.length) throw new Error("eof")
            const c = s[i]
            if (c === '+') { i++; return parseFactor() }
            if (c === '-') { i++; return -parseFactor() }
            if (c === '(') {
                i++
                const v = parseExpr()
                skipWs()
                if (i >= s.length || s[i] !== ')') throw new Error("paren")
                i++
                return v
            }
            let num = ""
            while (i < s.length && /[0-9.]/.test(s[i])) { num += s[i]; i++ }
            if (num.length === 0) throw new Error("num")
            return parseFloat(num)
        }

        const result = parseExpr()
        skipWs()
        if (i < s.length) throw new Error("trailing")
        return result
    }

    function tryMath(text) {
        const s = text.trim()
        if (s.length === 0 || s.length > 100) return null
        if (!/^[0-9+\-*/().\s%]+$/.test(s)) return null
        if (!/[0-9]/.test(s)) return null
        const ops = s.replace(/[0-9()\s.]/g, "")
        if (ops.length === 0) return null
        try {
            const r = root.evalMath(s)
            if (typeof r === "number" && isFinite(r)) return r
        } catch (e) {}
        return null
    }

    function fmtResult(r) {
        if (Math.abs(r - Math.round(r)) < 1e-9) return String(Math.round(r))
        return String(Math.round(r * 10000) / 10000)
    }

    function filterApps(q) {
        const lower = q.toLowerCase()
        const list = DesktopEntries.applications.values
        const out = []
        for (let i = 0; i < list.length; i++) {
            const app = list[i]
            if (app.noDisplay) continue
            if (lower.length === 0) {
                out.push(app)
                continue
            }
            const hay = (((app.name || "") + " "
                + (app.genericName || "") + " "
                + (app.categories || "") + " "
                + (app.keywords || "")).toLowerCase())
            if (hay.indexOf(lower) !== -1) out.push(app)
        }
        out.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
        return out
    }

    readonly property var items: {
        const q = searchInput.text.trim()
        const out = []
        if (q.length > 0) {
            const m = root.tryMath(q)
            if (m !== null) out.push({ type: "math", expr: q, result: m })
        }
        const apps = root.filterApps(q)
        const appLimit = q.length === 0 ? 60 : 6
        for (let i = 0; i < apps.length && i < appLimit; i++) {
            out.push({ type: "app", app: apps[i] })
        }
        if (q.length >= 2) {
            for (const f of root.fileResults) {
                out.push({ type: "file", name: f.name, path: f.path, isDir: f.isDir })
            }
        }
        return out
    }

    function gridHeight() {
        const n = root.items.length
        if (n === 0) return 60
        const rows = Math.min(n, 6)
        return rows * root.rowH + (rows - 1) * root.rowSpacing
    }

    function iconFor(entry) {
        if (entry == null) return ""
        const icon = entry.icon
        if (!icon) return ""
        if (icon.indexOf("/") === 0) return "file://" + icon
        const p = Quickshell.iconPath(icon)
        return p || ""
    }

    function rowTitle(row) {
        if (row.type === "math") return row.expr + " = " + root.fmtResult(row.result)
        if (row.type === "file") return row.name
        if (row.type === "app") return row.app ? (row.app.name || row.app.id || "") : ""
        return ""
    }

    function rowSubtitle(row) {
        if (row.type === "file") return row.path
        if (row.type === "app") return row.app ? (row.app.genericName || "") : ""
        return ""
    }

    function rowIcon(row) {
        if (row.type === "file") return Quickshell.iconPath(row.isDir ? "folder" : "text-x-generic")
        if (row.type === "app") return root.iconFor(row.app)
        return ""
    }

    function rowFallback(row) {
        if (row.type === "math") return "\uf1ec"
        if (row.type === "file") return "\uf07b"
        if (row.type === "app") return row.app && row.app.name ? row.app.name.charAt(0).toUpperCase() : "?"
        return "?"
    }

    function launchRow(row) {
        root.open = false
        launchTimer.payload = row
        launchTimer.restart()
    }

    function launchFirst() {
        if (root.items.length > 0) root.launchRow(root.items[0])
    }

    Timer {
        id: launchTimer
        interval: 80
        property var payload: null
        onTriggered: {
            if (!payload) return
            const row = payload
            if (row.type === "app") {
                if (row.app) row.app.execute()
            } else if (row.type === "file") {
                Quickshell.execDetached(["nautilus", row.path])
            } else if (row.type === "math") {
                Quickshell.clipboardText = root.fmtResult(row.result)
            }
        }
    }

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

            Rectangle {
                id: searchBox
                width: parent.width
                height: 40
                radius: 20
                color: "#2B261E"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: "#959187"
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: "Search apps, files, or math..."
                    color: "#656057"
                    font.pixelSize: 14
                }

                TextInput {
                    id: searchInput
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.right: parent.right
                    anchors.rightMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    clip: true
                    selectByMouse: true
                    selectionColor: "#5E86E0"
                    Keys.onReturnPressed: root.launchFirst()
                    Keys.onEscapePressed: root.open = false
                    onTextChanged: {
                        searchDebounce.restart()
                        if (text.trim().length < 2) root.fileResults = []
                    }
                }
            }

            Item {
                id: gridArea
                width: parent.width
                height: root.gridHeight()
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    orientation: ListView.Vertical
                    model: root.items
                    spacing: root.rowSpacing
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: cell
                        required property var modelData
                        width: list.width
                        height: root.rowH

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 12
                            color: cellMouse.containsMouse ? "#2B261E" : "transparent"
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Rectangle {
                                width: 36
                                height: 36
                                radius: 11
                                color: "#342D24"

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.rowIcon(cell.modelData).length === 0
                                    text: root.rowFallback(cell.modelData)
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: "#FFFFFF"
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                IconImage {
                                    anchors.fill: parent
                                    source: root.rowIcon(cell.modelData)
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: root.rowTitle(cell.modelData)
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: list.width - 100
                                }

                                Text {
                                    visible: root.rowSubtitle(cell.modelData).length > 0
                                    text: root.rowSubtitle(cell.modelData)
                                    color: "#959187"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: list.width - 100
                                }
                            }
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchRow(cell.modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.items.length === 0
                    text: "No results"
                    color: "#959187"
                    font.pixelSize: 13
                }
            }
        }
    }
}
