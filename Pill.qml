import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color color: "#11111B"
    property int topRadius: 16
    property int bottomRadius: 16
    property int inset: 24
    default property alias content: contentItem.data

    layer.enabled: true
    layer.effect: Shadow {}

    readonly property real pillLeft: inset
    readonly property real pillTop: 0
    readonly property real pillRight: width - inset
    readonly property real pillBottom: height

    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true

        ShapePath {
            id: pill
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            fillRule: ShapePath.WindingFill

            startX: root.pillLeft
            startY: root.pillTop + root.topRadius

            PathCubic {
                x: root.pillLeft + root.topRadius
                y: root.pillTop
                control1X: root.pillLeft
                control1Y: root.pillTop - root.topRadius * 0.8
                control2X: root.pillLeft - root.topRadius * 2.5
                control2Y: root.pillTop
            }

            PathLine { x: root.pillRight - root.topRadius; y: root.pillTop }

            PathCubic {
                x: root.pillRight
                y: root.pillTop + root.topRadius
                control1X: root.pillRight + root.topRadius * 2.5
                control1Y: root.pillTop
                control2X: root.pillRight
                control2Y: root.pillTop - root.topRadius * 0.8
            }

            PathLine { x: root.pillRight; y: root.pillBottom - root.bottomRadius }

            PathCubic {
                x: root.pillRight - root.bottomRadius
                y: root.pillBottom
                control1X: root.pillRight
                control1Y: root.pillBottom - root.bottomRadius * 0.45
                control2X: root.pillRight - root.bottomRadius * 0.45
                control2Y: root.pillBottom
            }

            PathLine { x: root.pillLeft + root.bottomRadius; y: root.pillBottom }

            PathCubic {
                x: root.pillLeft
                y: root.pillBottom - root.bottomRadius
                control1X: root.pillLeft + root.bottomRadius * 0.45
                control1Y: root.pillBottom
                control2X: root.pillLeft
                control2Y: root.pillBottom - root.bottomRadius * 0.45
            }

            PathLine { x: root.pillLeft; y: root.pillTop + root.topRadius }
        }
    }

    Item {
        id: contentItem
        x: root.inset
        y: 0
        width: root.width - root.inset * 2
        height: root.height
        clip: true
    }
}
