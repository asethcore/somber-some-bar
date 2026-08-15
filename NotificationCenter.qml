import QtQuick

Item {
    id: root

    property var model: null

    function clearAll() {
        if (root.model) root.model.clear()
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#15130E"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Item {
            width: parent.width
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf0f3  Notifications"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: "#FFFFFF"
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: clearBtn.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.model ? root.model.count + "" : "0"
                color: "#8e8e93"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
            }

            Rectangle {
                id: clearBtn
                anchors.right: parent.right
                anchors.rightMargin: 0
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.width + 16
                height: 22
                radius: 11
                color: "#1c1c20"
                border.width: 1
                border.color: "#2b2e35"

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear all"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: "#f5f5f7"
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAll()
                }
            }
        }

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - 34
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: col.implicitHeight

            Column {
                id: col
                width: flick.width
                spacing: 6

                Repeater {
                    model: root.model

                    delegate: Rectangle {
                        width: col.width
                        height: {
                            let h = 34
                            if (model.body !== "") h += 14
                            return h
                        }
                        radius: 10
                        color: "#1c1c20"
                        border.width: 1
                        border.color: "#2b2e35"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    width: parent.width - 24
                                    elide: Text.ElideRight
                                    text: model.summary !== "" ? model.summary : model.body
                                    color: "#FFFFFF"
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: 16
                                    text: "\uf00d"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: "#8e8e93"
                                    z: 2

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        onClicked: root.model.remove(index)
                                    }
                                }
                            }

                            Text {
                                visible: model.body !== "" && model.summary !== ""
                                width: parent.width
                                elide: Text.ElideRight
                                text: model.appName + "  \u00b7  " + model.body
                                color: "#8e8e93"
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.model.remove(index)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.model ? root.model.count === 0 : true
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf0f3"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 26
                color: Qt.rgba(1, 1, 1, 0.25)
            }

            Text {
                text: "No notifications"
                color: Qt.rgba(1, 1, 1, 0.25)
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
            }
        }
    }
}
