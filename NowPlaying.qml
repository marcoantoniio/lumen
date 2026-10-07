// Música tocando na ilha: capa do álbum + barrinhas animadas + título.

import QtQuick

Row {
    id: root

    spacing: 9

    // Capa do álbum
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 6
        color: Theme.surfaceHover
        clip: true

        Image {
            anchors.fill: parent
            source: Music.artUrl
            sourceSize: Qt.size(48, 48)
            smooth: true
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
        }
    }

    // Barrinhas (equalizador) — congelam quando pausado
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: 4

            Rectangle {
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: 3
                radius: 1.5
                color: Theme.accent
                height: 4

                SequentialAnimation on height {
                    running: Music.playing
                    loops: Animation.Infinite

                    // from explícito: sem ele o driver de animação assume
                    // from=0 ao (re)iniciar e a barra cai a 0 (o "salto")
                    NumberAnimation { from: 4; to: 14; duration: 260 + index * 60; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 14; to: 4; duration: 260 + index * 60; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 150)
        text: Music.title
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
        elide: Text.ElideRight
    }
}
