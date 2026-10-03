// Card de clima do Dashboard: temperatura atual e 2 "quadradinhos" na
// horizontal (empilhados), cada um com hora, temperatura, sensação, umidade,
// vento e chuva.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    implicitHeight: 116
    radius: 12
    color: Theme.surfaceHover

    ColumnLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Clima"
                color: Theme.foregroundDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Weather.icon
                font.family: Theme.iconFont
                font.pixelSize: 16
                color: Theme.accent
            }

            Text {
                text: Weather.available ? Weather.tempC + "°C" : "—"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
            }
        }

        Text {
            Layout.fillWidth: true
            text: Weather.available ? Weather.desc : "carregando…"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: Weather.available
            text: "Máx " + Weather.high + "° · Mín " + Weather.low + "° · Chuva " + Weather.rainChance + "%"
            color: Theme.foregroundDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        // 2 faixas horizontais (empilhadas), com hora acima do ícone
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Repeater {
                model: Weather.hourly

                delegate: RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    // Hora acima do ícone do tempo
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: Theme.foregroundDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.temp + "°"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Sens. " + modelData.feels + "°"
                                color: Theme.foregroundDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "\u{F058E}" // umidade
                                font.family: Theme.iconFont
                                font.pixelSize: 9
                                color: Theme.accentCool
                            }

                            Text {
                                text: modelData.humidity + "%"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Text {
                                text: "\u{F059D}" // vento
                                font.family: Theme.iconFont
                                font.pixelSize: 9
                                color: Theme.accentCool
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.wind + "km"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "\u{F0597}" // chuva
                                font.family: Theme.iconFont
                                font.pixelSize: 9
                                color: Theme.accentCool
                            }

                            Text {
                                text: modelData.rain + "%"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }
                        }
                    }
                }
            }
        }
    }
}
