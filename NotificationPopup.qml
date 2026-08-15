import QtQuick

Rectangle {
    id: root

    property string appName: ""
    property string summary: ""
    property string body: ""

    width: 400
    height: 76
    radius: 16
    color: "#110F0A"
    border.width: 1
    border.color: "#2b2e35"

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Text {
            width: 22
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -5
            horizontalAlignment: Text.AlignHCenter
            text: "\uf0f3"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            color: "#FFFFFF"
        }

        Column {
            width: parent.width - 22 - 12
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.appName
                elide: Text.ElideRight
                color: "#8e8e93"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
            }

            Text {
                width: parent.width
                text: root.summary !== "" ? root.summary : root.body
                elide: Text.ElideRight
                color: "#FFFFFF"
                font.pixelSize: 13
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: root.body
                elide: Text.ElideRight
                color: "#b0b0b5"
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
            }
        }
    }
}
