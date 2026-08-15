import QtQuick

Rectangle {
    id: root

    property bool active: false
    property string label: ""
    property string subtitle: ""
    property string icon: ""
    property string iconOff: ""
    signal clicked

    readonly property string shownIcon: root.active ? root.icon : (root.iconOff.length > 0 ? root.iconOff : root.icon)

    implicitWidth: 165
    implicitHeight: 72
    radius: height / 2
    color: "#2B261E"

    Rectangle {
        id: iconBlock
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 46
        radius: height / 2
        color: root.active ? "#5E86E0" : "#463F34"

        Text {
            anchors.centerIn: parent
            text: root.shownIcon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 21
            color: root.active ? "#FFFFFF" : "#C5C1B9"
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 64
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.label
            font.pixelSize: 13
            font.bold: true
            color: "#FFFFFF"
            visible: root.label.length > 0
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.subtitle
            font.pixelSize: 11
            color: "#959187"
            visible: root.subtitle.length > 0
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
