// Painel de teste da câmera: preview ao vivo (QtMultimedia) + escolha do
// dispositivo. Abre pelo botão "Câmera" do Control Center ou por IPC.
//
// A sessão de captura só é criada enquanto o painel está visível (Loader),
// para não segurar a câmera quando fechado.

import Quickshell
import QtMultimedia
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: panel

    property var panelWindow: null
    property var anchorItem: null

    readonly property int panelWidth: Theme.cameraPanelWidth
    readonly property var cameras: mediaDevices.videoInputs

    // Só no monitor principal (evita duas instâncias abrindo a câmera)
    readonly property bool primaryScreen: panelWindow !== null
        && Quickshell.screens.length > 0 && panelWindow.screen === Quickshell.screens[0]

    property var selectedDevice: null
    property string cameraError: ""

    anchor.window: panelWindow
    anchor.rect.x: anchorItem
                   ? anchorItem.x + (anchorItem.width - panelWidth) / 2
                   : (panelWindow ? panelWindow.width - panelWidth - Theme.barMargin : 0)
    anchor.rect.y: anchorItem
                   ? anchorItem.y + anchorItem.height - 1
                   : (panelWindow ? panelWindow.height + Theme.barMargin : 0)
    implicitWidth: panelWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    visible: Webcam.open && primaryScreen && !ControlCenter.open && !Notifications.centerOpen && !Music.panelOpen

    onVisibleChanged: {
        if (visible && selectedDevice === null && cameras.length > 0)
            selectedDevice = cameras[0];
        if (!visible && Webcam.open)
            Webcam.open = false;
    }

    MediaDevices {
        id: mediaDevices
    }

    Component {
        id: sessionComp

        CaptureSession {
            camera: Camera {
                cameraDevice: panel.selectedDevice
                active: panel.visible

                onErrorStringChanged: panel.cameraError = errorString
            }

            videoOutput: videoOutLoader.item
        }
    }

    Component {
        id: videoComp

        VideoOutput {
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
        }
    }

    Loader {
        id: sessionLoader

        active: panel.visible
        sourceComponent: sessionComp
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitHeight: column.implicitHeight + 24
        radius: Theme.radius
        topLeftRadius: 0
        topRightRadius: 0
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        opacity: panel.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        // Junção com a ilha
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 1
                rightMargin: 1
            }
            height: 1
            color: "#000000"
        }

        ColumnLayout {
            id: column

            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Câmera"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    visible: panel.cameraError !== ""
                    text: panel.cameraError
                    color: Theme.accentAlt
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(width * 9 / 16)
                radius: 10
                color: Theme.card
                clip: true

                Loader {
                    id: videoOutLoader

                    anchors.fill: parent
                    active: panel.visible
                    sourceComponent: videoComp
                }

                Text {
                    anchors.centerIn: parent
                    visible: panel.cameras.length === 0
                    text: "nenhuma câmera encontrada"
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: camFlow.implicitHeight

                Flow {
                    id: camFlow

                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: panel.cameras

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool current: panel.selectedDevice === modelData

                            implicitWidth: camLabel.implicitWidth + 22
                            implicitHeight: 24
                            radius: 12
                            color: current
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                   : Theme.surfaceHover
                            border.width: 1
                            border.color: current ? Theme.accent : "transparent"

                            Text {
                                id: camLabel

                                anchors.centerIn: parent
                                text: modelData.description !== "" ? modelData.description : modelData.id
                                color: current ? Theme.accent : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.selectedDevice = modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
