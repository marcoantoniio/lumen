// Relógio central da barra.

import Quickshell
import QtQuick

Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.Medium
    }
}
