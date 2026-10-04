// Aba Timer do Control Center: Pomodoro (tempos configuráveis), Cronômetro e
// Timer (contagem regressiva) — sub-abas.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property int mode: 0 // 0 = pomodoro, 1 = cronômetro, 2 = timer

    spacing: 10

    component TimerButton: Rectangle {
        id: button

        property string glyph: ""
        property color glyphColor: Theme.foreground
        property bool filled: false

        signal activated()

        implicitWidth: 42
        implicitHeight: 42
        radius: 21
        color: filled
               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
               : (buttonArea.containsMouse ? Theme.surfaceHover : "transparent")
        border.width: 1
        border.color: filled ? Theme.accent
                    : (buttonArea.containsMouse ? Theme.border : "transparent")

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: button.glyphColor
            font.family: Theme.iconFont
            font.pixelSize: 18
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    component StepButton: Rectangle {
        id: step

        property string glyph: ""

        signal activated()

        implicitWidth: 22
        implicitHeight: 22
        radius: 11
        color: stepArea.containsMouse ? Theme.surfaceHover : "transparent"
        border.width: 1
        border.color: stepArea.containsMouse ? Theme.border : "transparent"

        Text {
            anchors.centerIn: parent
            text: step.glyph
            color: Theme.foreground
            font.family: Theme.iconFont
            font.pixelSize: 11
        }

        MouseArea {
            id: stepArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: step.activated()
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
        spacing: 10

        Item { Layout.fillHeight: true }

        // tempos configuráveis
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Repeater {
                model: [
                    { label: "Foco", kind: "focus", minutes: TimerService.focusMinutes },
                    { label: "Pausa", kind: "short", minutes: TimerService.shortBreakMinutes },
                    { label: "Longa", kind: "long", minutes: TimerService.longBreakMinutes }
                ]

                delegate: RowLayout {
                    required property var modelData

                    spacing: 3

                    Text {
                        text: modelData.label
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    StepButton {
                        glyph: "\u{F0374}" // nf-md-minus
                        onActivated: TimerService.adjustPomodoro(modelData.kind, -5)
                    }

                    Text {
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.minutes + "min"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    StepButton {
                        glyph: "\u{F0415}" // nf-md-plus
                        onActivated: TimerService.adjustPomodoro(modelData.kind, 5)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.pomoLabel
            color: TimerService.pomoPhase === 1 ? Theme.accentAlt : Theme.accentCool
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.format(TimerService.pomoRemaining)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 46
            font.bold: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
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

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            TimerButton {
                glyph: TimerService.pomoRunning ? "\u{F03E4}" : "\u{F040A}" // pause / play
                filled: true
                onActivated: TimerService.pomoToggle()
            }

            TimerButton {
                glyph: "\u{F0709}" // nf-md-restart
                onActivated: TimerService.pomoReset()
            }

            TimerButton {
                glyph: "\u{F04AD}" // nf-md-skip_next (pular fase)
                onActivated: TimerService.pomoSkip()
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.pomoCompleted + (TimerService.pomoCompleted === 1 ? " pomodoro concluído" : " pomodoros concluídos")
            color: Theme.foregroundDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Item { Layout.fillHeight: true }
    }

    // ================= CRONÔMETRO =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.mode === 1
        spacing: 14

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.format(TimerService.swElapsed)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 46
            font.bold: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            TimerButton {
                glyph: TimerService.swRunning ? "\u{F03E4}" : "\u{F040A}" // pause / play
                filled: true
                onActivated: TimerService.swToggle()
            }

            TimerButton {
                glyph: "\u{F023B}" // nf-md-flag (volta)
                onActivated: TimerService.swLap()
            }

            TimerButton {
                glyph: "\u{F0709}" // nf-md-restart
                onActivated: TimerService.swReset()
            }
        }

        // voltas
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(120, lapsCol.implicitHeight)
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
        spacing: 10

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.timerRunning ? "Contando…" : "Timer"
            color: Theme.accentCool
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.format(TimerService.timerRemaining)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 46
            font.bold: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
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

        // tempos rápidos
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: [1, 3, 5, 10, 15, 30, 60]

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool current: TimerService.timerMinutes === modelData

                    implicitWidth: presetLabel.implicitWidth + 18
                    implicitHeight: 24
                    radius: 12
                    color: current
                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                           : Theme.surfaceHover
                    border.width: 1
                    border.color: current ? Theme.accent : "transparent"

                    Text {
                        id: presetLabel

                        anchors.centerIn: parent
                        text: modelData + "min"
                        color: current ? Theme.accent : Theme.foreground
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

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            TimerButton {
                glyph: TimerService.timerRunning ? "\u{F03E4}" : "\u{F040A}" // pause / play
                filled: true
                onActivated: TimerService.timerToggle()
            }

            TimerButton {
                glyph: "\u{F0374}" // nf-md-minus (1 min)
                onActivated: TimerService.timerAdjust(-1)
            }

            TimerButton {
                glyph: "\u{F0415}" // nf-md-plus (1 min)
                onActivated: TimerService.timerAdjust(1)
            }

            TimerButton {
                glyph: "\u{F0709}" // nf-md-restart
                onActivated: TimerService.timerReset()
            }
        }

        Item { Layout.fillHeight: true }
    }
}
