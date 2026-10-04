// Relógio central da barra.

import Quickshell
import QtQuick

Item {
    id: root

    // Versão compacta (só HH:mm, discreta) usada ao lado do "tocando agora"
    property bool compact: false

    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.compact
              ? Qt.formatDateTime(clock.date, "HH:mm")
              : Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
        color: root.compact ? Theme.foregroundDim : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: root.compact ? 12 : 13
        font.weight: Font.Medium
    }
}
