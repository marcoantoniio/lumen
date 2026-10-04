// Barra flutuante em pílula, uma instância por monitor.
//
// Comportamento (igual ao shell original):
// - Idle: só o relógio.
// - Hover: a pílula expande com animação e revela os elementos laterais.
// - Esquerda: dots de workspace + sino.
// - Direita: botões circulares coloridos (categorias de notificação).
// - A bandeja do sistema fica no rodapé do painel de notificações.
//
// Técnica: o PanelWindow ocupa a largura toda (com margens), mas a pílula
// interna tem só a largura do conteúdo. O `mask` faz os cliques fora da
// pílula passarem direto para as janelas de baixo.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    property bool expanded: false

    // Pequeno atraso ao sair, para não colapsar por tremor de borda
    Timer {
        id: collapseTimer
        interval: 160
        onTriggered: bar.expanded = false
    }

    // Painel de música: abre no hover (com atraso) quando há música tocando
    Timer {
        id: musicOpenTimer
        interval: 350
        onTriggered: {
            if (Music.active && !ControlCenter.open && !Notifications.centerOpen)
                Music.panelOpen = true;
        }
    }

    Timer {
        id: musicCloseTimer
        interval: 350
        onTriggered: if (!Music.panelHovered) Music.panelOpen = false
    }

    Connections {
        target: Music

        function onPanelHoveredChanged() {
            if (!Music.panelHovered && !barHover.hovered)
                musicCloseTimer.restart();
        }
    }

    Rectangle {
        id: pill

        anchors.centerIn: parent
        height: Theme.barHeight
        radius: Theme.barRadius
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        clip: true

        // 0 = colapsado, 1 = expandido (animado)
        property real reveal: bar.expanded ? 1 : 0

        Behavior on reveal {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // Largura simétrica: os dois lados usam a largura do cluster maior,
        // mantendo o relógio centralizado e sem encostar nos botões.
        readonly property real sideWidth: Math.max(leftRow.implicitWidth, rightRow.implicitWidth)

        // Quando um painel está aberto, a ilha cresce até a largura dele
        // e encosta no painel (cantos de baixo retos).
        readonly property real panelTargetWidth: ControlCenter.open
            ? Theme.controlCenterPanelWidth
            : (Notifications.centerOpen ? Theme.notificationPanelWidth
            : (Music.panelOpen ? Theme.musicPanelWidth : 0))

        property real animatedPanelWidth: panelTargetWidth

        Behavior on animatedPanelWidth {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // Item central: volume (OSD) > gravação > música > relógio
        readonly property string centerMode: Audio.osdVisible ? "volume"
            : Recorder.recording ? "rec"
            : (Music.playing ? "music" : "clock")

        readonly property real centerWidth: centerMode === "volume" ? volumeOsd.implicitWidth
            : centerMode === "rec" ? recIndicator.implicitWidth
            : centerMode === "music" ? nowPlaying.implicitWidth
            : clockItem.implicitWidth

        width: Math.max(centerWidth + Theme.pillPadding * 2
                        + reveal * (sideWidth * 2 + Theme.spacing * 2),
                        animatedPanelWidth)

        bottomLeftRadius: panelTargetWidth > 0 ? 0 : Theme.barRadius
        bottomRightRadius: panelTargetWidth > 0 ? 0 : Theme.barRadius

        Behavior on bottomLeftRadius {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: barHover

            onHoveredChanged: {
                if (barHover.hovered) {
                    collapseTimer.stop();
                    bar.expanded = true;
                    musicCloseTimer.stop();
                    if (Music.active && !ControlCenter.open && !Notifications.centerOpen)
                        musicOpenTimer.start();
                } else {
                    collapseTimer.start();
                    musicOpenTimer.stop();
                    musicCloseTimer.start();
                }
            }
        }

        // ---- esquerda: dots de workspace + sino ----
        Item {
            id: leftWrap

            width: pill.sideWidth
            height: Theme.barHeight
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.pillPadding - (1 - pill.reveal) * width
            }
            opacity: pill.reveal

            Row {
                id: leftRow

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8

                WorkspacePills {}

                Bell {}
            }
        }

        // ---- centro: relógio, gravação, volume ou música ----
        Clock {
            id: clockItem
            anchors.centerIn: parent
            visible: pill.centerMode === "clock"
        }

        RecordingIndicator {
            id: recIndicator
            anchors.centerIn: parent
            visible: pill.centerMode === "rec"
        }

        VolumeOsd {
            id: volumeOsd
            anchors.centerIn: parent
            visible: pill.centerMode === "volume"
        }

        NowPlaying {
            id: nowPlaying
            anchors.centerIn: parent
            visible: pill.centerMode === "music"
        }

        // ---- direita: botões de categoria ----
        Item {
            id: rightWrap

            width: pill.sideWidth
            height: Theme.barHeight
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Theme.pillPadding - (1 - pill.reveal) * width
            }
            opacity: pill.reveal

            Row {
                id: rightRow

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8

                CategoryButtons {}
            }
        }
    }

    // Só a pílula recebe cliques; o resto da faixa é click-through
    mask: Region {
        item: pill
    }

    // Caffeine: associado à janela da barra, ativo enquanto ligado no
    // Control Center (ou via IPC).
    IdleInhibitor {
        window: bar
        enabled: ControlCenter.caffeineEnabled
    }

    NotificationPopups {
        panelWindow: bar
    }

    NotificationCenter {
        panelWindow: bar
        anchorItem: pill
    }

    ControlCenterPanel {
        panelWindow: bar
        anchorItem: pill
    }

    MusicPanel {
        panelWindow: bar
        anchorItem: pill
    }
}
