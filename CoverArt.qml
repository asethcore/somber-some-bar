import Quickshell.Widgets
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
        const cur = artImg.source
        artImg.source = ""
        artImg.source = cur
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.bgColor

        Image {
            id: artImg
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(512, 512)
            source: root.resolved
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

    Timer {
        id: artRetry
        interval: 4000
        repeat: true
        running: root.resolved !== "" && (artImg.status === Image.Error || artImg.status === Image.Null)
        onTriggered: root.refresh()
    }
}
