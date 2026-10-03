// Ícones da bandeja do sistema (StatusNotifierItem).
// Esquerdo: ativar. Meio: ativação secundária. Direito: menu do item.

import QtQuick
import Quickshell.Services.SystemTray

Row {
    id: root

    property var panelWindow: null

    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property var modelData

            implicitWidth: 18
            implicitHeight: 18
            visible: modelData.icon !== ""

            Image {
                anchors.fill: parent
                source: entry.modelData.icon
                sourceSize: Qt.size(16, 16)
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        entry.modelData.activate();
                    else if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else if (mouse.button === Qt.RightButton && entry.modelData.hasMenu)
                        entry.modelData.display(root.panelWindow, 0, root.height);
                }
            }
        }
    }
}
