// Painel "Recentes": arquivos mais novos de Downloads/Pictures/Documents/Videos
// para abrir com um clique (hub do botão ciano da ilha).

import Quickshell
import QtQuick

PopupWindow {
    id: panel

    property var panelWindow: null
    property var anchorItem: null

    readonly property int panelWidth: Theme.recentPanelWidth

    anchor.window: panelWindow
    anchor.rect.x: anchorItem
                   ? anchorItem.x + (anchorItem.width - panelWidth) / 2
                   : (panelWindow ? panelWindow.width - panelWidth - Theme.barMargin : 0)
    anchor.rect.y: anchorItem
                   ? anchorItem.y + anchorItem.height - 1
                   : (panelWindow ? panelWindow.height + Theme.barMargin : 0)
    implicitWidth: panelWidth
    // Altura fixa: redimensionar a janela no Wayland glicha (hover se perde)
    implicitHeight: 352
    color: "transparent"
    visible: RecentFiles.open && !ControlCenter.open && !Notifications.centerOpen

    onVisibleChanged: {
        // Qt.callLater evita binding loop no visible (bug de flicker)
        if (!visible && RecentFiles.open)
            Qt.callLater(() => RecentFiles.open = false);
    }

    // Ícone por tipo de arquivo (glifos conferidos na Nerd Font)
    function iconFor(name) {
        const ext = name.substring(name.lastIndexOf(".") + 1).toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"].includes(ext))
            return "\u{F02E9}"; // imagem
        if (["mp4", "mkv", "webm", "mov", "avi", "m4v"].includes(ext))
            return "\u{F0100}"; // vídeo
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus", "aac"].includes(ext))
            return "\u{F075A}"; // áudio
        if (["zip", "tar", "gz", "xz", "7z", "rar", "zst"].includes(ext))
            return "\u{F01A7}"; // pacote
        if (["qml", "js", "ts", "py", "sh", "json", "html", "css", "c", "cpp", "h",
             "rs", "go", "toml", "yaml", "yml", "conf", "ini"].includes(ext))
            return "\u{F0A0A}"; // código
        if (["pdf", "txt", "md", "doc", "docx", "odt", "rtf", "csv", "xls", "xlsx",
             "ods", "ppt", "pptx"].includes(ext))
            return "\u{F0219}"; // documento
        return "\u{F0214}"; // genérico
    }

    function relTime(ts) {
        const diff = Date.now() / 1000 - ts;
        if (diff < 60)
            return "agora";
        if (diff < 3600)
            return "há " + Math.floor(diff / 60) + " min";
        if (diff < 86400)
            return "há " + Math.floor(diff / 3600) + " h";
        return Qt.formatDateTime(new Date(ts * 1000), "dd/MM HH:mm");
    }

    Rectangle {
        id: frame

        width: parent.width
        height: parent.height
        radius: Theme.radius
        topLeftRadius: 0
        topRightRadius: 0
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        HoverHandler {
            onHoveredChanged: RecentFiles.panelHovered = hovered
        }

        opacity: panel.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        // Junção com a ilha: esconde a borda de cima
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

        Text {
            id: title

            anchors {
                top: parent.top
                left: parent.left
                topMargin: 12
                leftMargin: 14
            }
            text: "Recentes"
            color: Theme.foregroundDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            id: closeBtn

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 8
                rightMargin: 14
            }
            text: "✕"
            color: closeArea.containsMouse ? Theme.foreground : Theme.foregroundDim
            font.family: Theme.fontFamily
            font.pixelSize: 13

            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: RecentFiles.open = false
            }
        }

        ListView {
            id: list

            anchors {
                top: title.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 10
                leftMargin: 12
                rightMargin: 12
                bottomMargin: 12
            }
            clip: true
            spacing: 2
            model: RecentFiles.files

            delegate: Rectangle {
                id: fileRow

                required property var modelData

                width: ListView.view.width
                height: 32
                radius: 8
                color: rowArea.containsMouse ? Theme.surfaceHover : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                Text {
                    id: fileIcon

                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: panel.iconFor(fileRow.modelData.name)
                    color: Theme.foregroundDim
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                }

                Column {
                    anchors {
                        left: fileIcon.right
                        leftMargin: 10
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 1

                    Text {
                        width: parent.width
                        text: fileRow.modelData.name
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }

                    Text {
                        width: parent.width
                        text: fileRow.modelData.dir + " · " + panel.relTime(fileRow.modelData.ts)
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: rowArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["xdg-open", fileRow.modelData.path]);
                        RecentFiles.open = false;
                    }
                }
            }
        }

        Text {
            anchors.centerIn: list
            visible: RecentFiles.files.length === 0
            text: "nada por aqui"
            color: Theme.foregroundDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
}
