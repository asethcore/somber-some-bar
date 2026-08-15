import QtQuick

Item {
    id: root

    property real value: 0
    property color trackColor: "#463F34"
    property color fillColor: "#5E86E0"
    property real trackHeight: 6
    signal moved(real v)

    property bool dragging: false
    property real dragVal: 0

    readonly property real shown: root.dragging ? root.dragVal : root.value
    readonly property real norm: Math.min(1, Math.max(0, root.shown / 100))

    implicitHeight: 24
    implicitWidth: 200

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.trackHeight
        radius: height / 2
        color: root.trackColor

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.norm
            height: parent.height
            radius: height / 2
            color: root.fillColor
        }
    }

    Rectangle {
        id: handle
        width: 14
        height: 14
        radius: 7
        color: "#000000"
        border.width: 1
        border.color: "#564E43"
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round((parent.width - width) * root.norm)
        Behavior on x {
            enabled: !root.dragging
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (event) => {
            root.dragging = true
            updateVal(event.x)
        }
        onPositionChanged: (event) => {
            if (pressed) updateVal(event.x)
        }
        onReleased: {
            root.dragging = false
            root.moved(root.dragVal)
        }
        function updateVal(mx) {
            root.dragVal = 100 * Math.min(1, Math.max(0, mx / width))
        }
    }
}
