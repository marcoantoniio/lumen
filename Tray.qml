// Ícones da bandeja do sistema (StatusNotifierItem).
// Esquerdo: ativar (ou abrir o menu, se o item só tiver menu). Meio: ativação
// secundária. Direito: menu do item (DBusMenu) ancorado ao ícone.

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Row {
    id: root

    spacing: 6

    Repeater {
        id: items

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

            // Menu do item (DBusMenu), ancorado ao ícone
            QsMenuAnchor {
                id: menuAnchor

                menu: entry.modelData.menu
                anchor.item: entry
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        if (entry.modelData.onlyMenu && entry.modelData.hasMenu)
                            menuAnchor.open();
                        else
                            entry.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton && entry.modelData.hasMenu) {
                        menuAnchor.open();
                    }
                }
            }
        }
    }
}
