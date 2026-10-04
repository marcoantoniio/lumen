// Aba Timer do Control Center: Pomodoro (tempos ajustáveis), Cronômetro e
// Timer (contagem regressiva) — sub-abas.
// Layout: tempo à esquerda e botões quadradinhos à direita.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property int mode: 0 // 0 = pomodoro, 1 = cronômetro, 2 = timer

    spacing: 8

    // Botão quadradinho com ícone
    component SquareButton: Rectangle {
        id: button

        property string glyph: ""
        property bool primary: false

        signal activated()

        implicitWidth: 40
        implicitHeight: 40
        radius: 12
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
            font.pixelSize: 17
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    // ---- sub-abas ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

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

        // tempo à esquerda, botões à direita
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.leftMargin: 6
                text: TimerService.format(TimerService.pomoRemaining)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 40
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            SquareButton {
                glyph: "\u{F0374}" // nf-md-minus
                onActivated: TimerService.pomoAdjust(-5)
            }

            SquareButton {
                glyph: "\u{F0415}" // nf-md-plus
                onActivated: TimerService.pomoAdjust(5)
            }

            Item { Layout.preferredWidth: 2 }

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

        // progresso
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitHeight: 5
            radius: 2.5
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

        // status + durações (clique alterna os presets)
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (TimerService.pomoPhase === 0 ? "Pronto" : TimerService.pomoLabel)
                      + " · " + TimerService.pomoCompleted
                      + (TimerService.pomoCompleted === 1 ? " concluído" : " concluídos")
                color: Theme.foregroundDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Repeater {
                model: [
                    { label: "Foco", kind: "focus", minutes: TimerService.focusMinutes },
                    { label: "Pausa", kind: "short", minutes: TimerService.shortBreakMinutes },
                    { label: "Longa", kind: "long", minutes: TimerService.longBreakMinutes }
                ]

                delegate: Text {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label + " " + modelData.minutes + "min"
                    color: chipArea.containsMouse ? Theme.accent : Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TimerService.cyclePomodoro(modelData.kind)
                    }
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
            spacing: 8

            Text {
                Layout.leftMargin: 6
                text: TimerService.format(TimerService.swElapsed)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 40
                font.bold: true
            }

            Item { Layout.fillWidth: true }

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
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.leftMargin: 6
                text: TimerService.format(TimerService.timerRemaining)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 40
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            SquareButton {
                glyph: "\u{F0374}" // nf-md-minus (1 min)
                onActivated: TimerService.timerAdjust(-1)
            }

            SquareButton {
                glyph: "\u{F0415}" // nf-md-plus (1 min)
                onActivated: TimerService.timerAdjust(1)
            }

            Item { Layout.preferredWidth: 2 }

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

        // progresso
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitHeight: 5
            radius: 2.5
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

        // tempos rápidos
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: [1, 3, 5, 10, 15, 30, 60]

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool current: TimerService.timerMinutes === modelData

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: presetLabel.implicitWidth + 16
                    implicitHeight: 24
                    radius: 8
                    color: current
                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                           : Theme.surfaceHover
                    border.width: 1
                    border.color: current ? Theme.accent : "transparent"

                    Text {
                        id: presetLabel

                        anchors.centerIn: parent
                        text: modelData + "min"
                        color: current ? Theme.accent : Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TimerService.timerSet(modelData)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
