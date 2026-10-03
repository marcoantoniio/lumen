// Card de calendário do Dashboard: semana atual (iniciais + dia de hoje em
// pílula clara), mini-mês completo abaixo e o nº da semana no rodapé.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    implicitHeight: 116
    radius: 12
    color: Theme.surfaceHover

    property int tick: 0

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    readonly property var monthNames: ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

    function isoWeek(d) {
        const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dayNum = date.getUTCDay() || 7;
        date.setUTCDate(date.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
        return Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
    }

    readonly property var week: {
        root.tick; // reavalia a cada minuto (vira o dia à meia-noite)
        const now = new Date();
        const dow = now.getDay();
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dow);
        const initials = ["D", "S", "T", "Q", "Q", "S", "S"];
        const days = [];
        for (let i = 0; i < 7; ++i) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            days.push({ initial: initials[i], num: d.getDate(), today: d.toDateString() === now.toDateString() });
        }
        const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 6);
        const range = start.getDate() + " " + root.monthNames[start.getMonth()] + " – " + end.getDate() + " " + root.monthNames[end.getMonth()];
        return { days: days, range: range, week: isoWeek(now) };
    }

    // Mini-mês: dias do mês atual com hoje destacado
    readonly property var month: {
        root.tick;
        const now = new Date();
        const y = now.getFullYear();
        const m = now.getMonth();
        const startDow = new Date(y, m, 1).getDay();
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < startDow; ++i)
            cells.push({ num: 0, today: false });
        for (let d = 1; d <= daysInMonth; ++d)
            cells.push({ num: d, today: d === now.getDate() });
        while (cells.length % 7 !== 0)
            cells.push({ num: 0, today: false });
        return { name: root.monthNames[m] + " " + y, cells: cells };
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: root.week.range
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Row {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.week.days

                delegate: Item {
                    required property var modelData

                    width: (root.width - 16) / 7
                    implicitHeight: 42

                    Rectangle {
                        anchors.centerIn: parent
                        width: 18
                        height: 38
                        radius: 9
                        color: modelData.today ? "#efeceb" : "transparent"

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.initial
                                color: modelData.today ? "#111111" : Theme.foregroundDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.num
                                color: modelData.today ? "#111111" : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: modelData.today
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.month.name
            color: Theme.foregroundDim
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 1

            Repeater {
                model: root.month.cells

                delegate: Item {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 16

                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        radius: 8
                        visible: modelData.num > 0
                        color: modelData.today ? "#efeceb" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            visible: modelData.num > 0
                            text: modelData.num
                            color: modelData.today ? "#111111" : Theme.foregroundDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: modelData.today
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            text: "Semana " + root.week.week
            color: Theme.foregroundDim
            font.family: Theme.fontFamily
            font.pixelSize: 8
        }
    }
}
