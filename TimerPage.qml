// Aba Timer do Control Center: Pomodoro e Cronômetro (sub-abas).

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property int mode: 0 // 0 = pomodoro, 1 = cronômetro

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

        Item { Layout.fillWidth: true }
    }

    // ================= POMODORO =================
    ColumnLayout {
        id: pomoCol

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.mode === 0
        spacing: 14

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.pomoLabel
            color: TimerService.pomoPhase === 1 ? Theme.accentAlt : Theme.accentCool
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            id: pomoTime

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
}
