// Painel central de notificações (histórico), ancorado logo abaixo da pílula
// (a "ilha dinâmica"), centralizado com ela.
// - Abas coloridas por categoria (mesmas cores dos botões da barra).
// - Filtra a lista pela categoria ativa.
// Abre/fecha via clique no sino ou:
//   qs -c lumen ipc call notifications toggle

import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: center

    property var panelWindow: null

    // Item (a pílula) embaixo do qual o painel deve abrir.
    // Como a pílula é sempre centralizada, o painel fica centralizado na tela.
    property var anchorItem: null

    readonly property int panelWidth: Theme.notificationPanelWidth

    anchor.window: panelWindow
    anchor.rect.x: anchorItem
                   ? anchorItem.x + (anchorItem.width - panelWidth) / 2
                   : (panelWindow ? panelWindow.width - panelWidth - Theme.barMargin : 0)
    anchor.rect.y: anchorItem
                   ? anchorItem.y + anchorItem.height - 1
                   : (panelWindow ? panelWindow.height + Theme.barMargin : 0)
    implicitWidth: panelWidth
    // Altura congelada ao abrir: fechar uma notificação (ou chegar nova) não
    // pode redimensionar a janela no Wayland (glicha e o painel pula/fecha).
    property real frozenHeight: 0
    implicitHeight: frozenHeight > 0 ? frozenHeight : Math.min(540, frame.implicitHeight)
    color: "transparent"
    visible: Notifications.centerOpen

    onVisibleChanged: {
        // congela a altura do conteúdo atual (sem redimensionar enquanto aberto)
        if (visible) {
            frozenHeight = 0;
            Qt.callLater(() => frozenHeight = Math.min(540, frame.implicitHeight));
        }
        // Qt.callLater evita binding loop no visible (bug de flicker)
        if (!visible && Notifications.centerOpen)
            Qt.callLater(() => Notifications.centerOpen = false);
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

        HoverHandler {
            onHoveredChanged: Notifications.panelHovered = hovered
        }

        opacity: center.visible ? 1 : 0
        scale: center.visible ? 1 : 0.97

        // Junção com a ilha: esconde a borda de cima (sem linha divisória)
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

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: column

            anchors {
                fill: parent
                margins: 12
            }
            spacing: 10

            // ---- cabeçalho ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Notificações"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    visible: Notifications.count > 0
                    text: String(Notifications.count)
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: Notifications.count > 0
                    text: "limpar tudo"
                    color: clearArea.containsMouse ? Theme.foreground : Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.clearAll()
                    }
                }

                Text {
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.foreground : Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.centerOpen = false
                    }
                }
            }

            // ---- abas de categoria ----
            Flickable {
                Layout.fillWidth: true
                implicitHeight: 24
                contentWidth: tabs.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: tabs
                    spacing: 6

                    FilterTab {
                        label: "Todas"
                        tabColor: Theme.accent
                        selected: Notifications.activeCategory === ""
                        onActivated: Notifications.activeCategory = ""
                    }

                    Repeater {
                        model: Notifications.categories

                        delegate: FilterTab {
                            required property var modelData

                            label: modelData.name + " " + modelData.count
                            tabColor: modelData.color
                            selected: Notifications.activeCategory === modelData.name
                            onActivated: Notifications.activeCategory = modelData.name
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            // ---- estado vazio ----
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                visible: Notifications.filtered.length === 0
                text: Notifications.activeCategory === ""
                      ? "Nenhuma notificação"
                      : "Nada em \"" + Notifications.activeCategory + "\""
                color: Theme.foregroundDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                topPadding: 24
                bottomPadding: 24
            }

            // ---- lista ----
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(400, list.implicitHeight)
                visible: Notifications.filtered.length > 0
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: list
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: Notifications.filtered

                        delegate: Rectangle {
                            required property var modelData

                            width: list.width
                            implicitHeight: itemColumn.implicitHeight + 20
                            radius: 10
                            color: Theme.card

                            ColumnLayout {
                                id: itemColumn
                                anchors {
                                    fill: parent
                                    margins: 10
                                }
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Notifications.colorFor(modelData.appName)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.appName
                                        color: Theme.foregroundDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "✕"
                                        color: dismissArea.containsMouse ? Theme.urgent : Theme.foregroundDim
                                        font.pixelSize: 11

                                        MouseArea {
                                            id: dismissArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Notifications.dismiss(modelData)
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.summary
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: modelData.body !== ""
                                    text: modelData.body
                                    textFormat: Text.PlainText
                                    color: Theme.foregroundDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // ---- rodapé: bandeja do sistema (como no original) ----
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "System Tray"
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Item { Layout.fillWidth: true }

                Tray {
                    id: tray

                    onMenuOpenChanged: Notifications.menuOpen = tray.menuOpen
                }
            }
        }
    }
}
