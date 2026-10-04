// Aba Timer do Control Center: Pomodoro (tempos ajustáveis), Cronômetro e
// Timer (contagem regressiva) — sub-abas.
// Layout: bloco do tempo (label + tempo + barra, centralizados) à esquerda e
// os botões em coluna vertical à direita.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property int mode: 0 // 0 = pomodoro, 1 = cronômetro, 2 = timer

    spacing: 10


    // Botão quadradinho com ícone
    component SquareButton: Rectangle {
        id: button

        property string glyph: ""
        property bool primary: false

        signal activated()

        implicitWidth: 34
        implicitHeight: 34
        radius: 10
        color: button.primary
               ? (buttonArea.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
               : (buttonArea.containsMouse
                  ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                  : Theme.surfaceHover)
        border.width: 1
        border.color: button.primary
                      ? "transparent"
                      : (buttonArea.containsMouse ? Theme.accent : "transparent")

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: button.primary ? Theme.accentInk : Theme.foreground
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    // Chip pequeno (durações/presets)
    component TimeChip: Rectangle {
        id: chip

        property string text: ""
        property bool current: false

        signal activated()

        implicitWidth: chipLabel.implicitWidth + 16
        implicitHeight: 22
        radius: 7
        color: chip.current
               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
               : (chipArea.containsMouse
                  ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                  : Theme.surfaceHover)
        border.width: 1
        border.color: chip.current ? Theme.accent : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            id: chipLabel

            anchors.centerIn: parent
            text: chip.text
            color: chip.current ? Theme.accent : (chipArea.containsMouse ? Theme.accent : Theme.foregroundDim)
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()
        }
    }

    // ---- sub-abas ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        PanelTab {
            label: "Pomodoro"
            selected: root.mode === 0
            onActivated: root.mode = 0
        }

        PanelTab {
            label: "Cronômetro"
            selected: root.mode === 1
            onActivated: root.mode = 1
        }

        PanelTab {
            label: "Timer"
            selected: root.mode === 2
            onActivated: root.mode = 2
        }

        Item { Layout.fillWidth: true }
    }

    // ================= POMODORO =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.mode === 0
        spacing: 12

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Item { Layout.fillWidth: true }

            // bloco do tempo (label + tempo + barra + chips, centralizados)
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: (TimerService.pomoPhase === 0 ? "Pronto" : TimerService.pomoLabel)
                          + " · " + TimerService.pomoCompleted
                          + (TimerService.pomoCompleted === 1 ? " concluído" : " concluídos")
                    color: TimerService.pomoPhase === 1 ? Theme.accentAlt : Theme.accentCool
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    id: pomoTime

                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.format(TimerService.pomoRemaining)
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 42
                    font.bold: true
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.max(120, pomoTime.implicitWidth)
                    implicitHeight: 6
                    radius: 3
                    color: Theme.surfaceHover

                    Rectangle {
                        width: Math.max(0, Math.min(1, TimerService.pomoProgress)) * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: TimerService.pomoPhase === 1 ? Theme.accentAlt : Theme.accentCool

                        Behavior on width {
                            NumberAnimation { duration: 250 }
                        }
                    }
                }

            }

            // botões em coluna
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 5

                SquareButton {
                    glyph: "\u{F0374}" // nf-md-minus
                    onActivated: TimerService.pomoAdjust(-5)
                }

                SquareButton {
                    glyph: "\u{F0415}" // nf-md-plus
                    onActivated: TimerService.pomoAdjust(5)
                }

                SquareButton {
                    glyph: TimerService.pomoRunning ? "\u{F03E4}" : "\u{F040A}" // pause / play
                    primary: true
                    onActivated: TimerService.pomoToggle()
                }

                SquareButton {
                    glyph: "\u{F0709}" // nf-md-restart
                    onActivated: TimerService.pomoReset()
                }

                SquareButton {
                    glyph: "\u{F04AD}" // nf-md-skip_next (pular fase)
                    onActivated: TimerService.pomoSkip()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // durações (clique alterna os presets)
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: [
                    { label: "Foco", kind: "focus", minutes: TimerService.focusMinutes },
                    { label: "Pausa", kind: "short", minutes: TimerService.shortBreakMinutes },
                    { label: "Longa", kind: "long", minutes: TimerService.longBreakMinutes }
                ]

                delegate: TimeChip {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label + " " + modelData.minutes + "min"
                    onActivated: TimerService.cyclePomodoro(modelData.kind)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ================= CRONÔMETRO =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.mode === 1
        spacing: 12

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                horizontalAlignment: Text.AlignHCenter
                text: TimerService.format(TimerService.swElapsed)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 42
                font.bold: true
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 5

                SquareButton {
                    glyph: TimerService.swRunning ? "\u{F03E4}" : "\u{F040A}" // pause / play
                    primary: true
                    onActivated: TimerService.swToggle()
                }

                SquareButton {
                    glyph: "\u{F023B}" // nf-md-flag (volta)
                    onActivated: TimerService.swLap()
                }

                SquareButton {
                    glyph: "\u{F0709}" // nf-md-restart
                    onActivated: TimerService.swReset()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // voltas
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(110, lapsCol.implicitHeight)
            contentHeight: lapsCol.implicitHeight
            clip: true
            interactive: contentHeight > height
            visible: TimerService.laps.length > 0

            Column {
                id: lapsCol

                width: parent.width
                spacing: 3

                Repeater {
                    model: TimerService.laps

                    delegate: RowLayout {
                        required property var modelData
                        required property int index

                        width: lapsCol.width
                        spacing: 8

                        Text {
                            text: "Volta " + (TimerService.laps.length - index)
                            color: Theme.foregroundDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: TimerService.format(modelData)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ================= TIMER (contagem regressiva) =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.mode === 2
        spacing: 12

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: TimerService.timerRunning ? "Contando…" : "Timer"
                    color: Theme.accentCool
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    id: timerTime

                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.format(TimerService.timerRemaining)
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 42
                    font.bold: true
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.max(120, pomoTime.implicitWidth)
                    implicitHeight: 6
                    radius: 3
                    color: Theme.surfaceHover

                    Rectangle {
                        width: Math.max(0, Math.min(1, TimerService.timerProgress)) * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accentCool

                        Behavior on width {
                            NumberAnimation { duration: 250 }
                        }
                    }
                }

            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 5

                SquareButton {
                    glyph: "\u{F0374}" // nf-md-minus (1 min)
                    onActivated: TimerService.timerAdjust(-1)
                }

                SquareButton {
                    glyph: "\u{F0415}" // nf-md-plus (1 min)
                    onActivated: TimerService.timerAdjust(1)
                }

                SquareButton {
                    glyph: TimerService.timerRunning ? "\u{F03E4}" : "\u{F040A}" // pause / play
                    primary: true
                    onActivated: TimerService.timerToggle()
                }

                SquareButton {
                    glyph: "\u{F0709}" // nf-md-restart
                    onActivated: TimerService.timerReset()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // tempos rápidos
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: [1, 3, 5, 10, 15, 30, 60]

                delegate: TimeChip {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData + "min"
                    current: TimerService.timerMinutes === modelData
                    onActivated: TimerService.timerSet(modelData)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
