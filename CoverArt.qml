import QtQuick

Item {
    id: root

    property string artUrl: ""
    property string trackUrl: ""
    property string bgColor: "#3C362C"
    property real radius: width / 2

    readonly property string resolved: {
        const art = root.artUrl
        if (art) {
            if (art.indexOf("spotify:image:") === 0) return "https://i.scdn.co/image/" + art.slice(14)
            if (art.indexOf("://") !== -1 || art.indexOf("data:") === 0) return art
            return "file://" + encodeURI(art)
        }
        const u = root.trackUrl
        if (!u) return ""
        let m = /(?:youtube\.com\/(?:watch\?v=|shorts\/|embed\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/.exec(u)
        if (m) return "https://i.ytimg.com/vi/" + m[1] + "/hqdefault.jpg"
        m = /vimeo\.com\/(\d+)/.exec(u)
        if (m) return "https://vumbnail.com/" + m[1] + ".jpg"
        return ""
    }

    function refresh() {
        canvas.requestPaint()
    }

    Image {
        id: artImg
        visible: true
        opacity: 0
        anchors.fill: parent
        source: root.resolved
        asynchronous: true
        sourceSize: Qt.size(512, 512)
        onStatusChanged: {
            canvas.requestPaint()
            if (artImg.status === Image.Ready) {
                artLoadTimer.stop()
                paintSettle.restart()
            }
        }
        onSourceChanged: canvas.requestPaint()
    }

    onArtUrlChanged: {
        artLoadTimer.restart()
        canvas.requestPaint()
        paintSettle.restart()
    }
    onTrackUrlChanged: {
        artLoadTimer.restart()
        canvas.requestPaint()
    }
    onResolvedChanged: {
        artLoadTimer.restart()
        canvas.requestPaint()
    }

    onVisibleChanged: {
        if (root.visible) {
            artLoadTimer.restart()
            canvas.requestPaint()
            paintSettle.restart()
        }
    }

    Timer {
        id: artLoadTimer
        interval: 100
        repeat: true
        running: root.visible && root.resolved !== "" && artImg.status !== Image.Ready
        onTriggered: canvas.requestPaint()
    }

    Timer {
        id: artRetry
        interval: 4000
        repeat: true
        running: root.resolved !== "" && (artImg.status === Image.Error || artImg.status === Image.Null)
        onTriggered: {
            const cur = artImg.source
            artImg.source = ""
            artImg.source = cur
        }
    }

    Timer {
        id: paintSettle
        interval: 150
        onTriggered: canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const r = Math.min(root.radius, width / 2, height / 2)
            ctx.beginPath()
            ctx.moveTo(r, 0)
            ctx.arcTo(width, 0, width, height, r)
            ctx.arcTo(width, height, 0, height, r)
            ctx.arcTo(0, height, 0, 0, r)
            ctx.arcTo(0, 0, width, 0, r)
            ctx.closePath()
            ctx.fillStyle = root.bgColor
            ctx.fill()
            if (artImg.status === Image.Ready && artImg.sourceSize.width > 0 && artImg.sourceSize.height > 0) {
                ctx.clip()
                const iw = artImg.sourceSize.width
                const ih = artImg.sourceSize.height
                const s = Math.max(width / iw, height / ih)
                const dw = iw * s
                const dh = ih * s
                ctx.drawImage(artImg, (width - dw) / 2, (height - dh) / 2, dw, dh)
                ctx.restore()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "\uf001"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: parent.width * 0.4
        color: "#959187"
        visible: artImg.status !== Image.Ready
    }
}
