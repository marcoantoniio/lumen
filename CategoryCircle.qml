// Botão circular de ação (usado na barra): só a cor, sem ícone nem anel.
// O selecionado ganha um brilho (gradiente radial suave).
// Tamanho enxuto, estilo ilha da Apple.

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color dotColor: Theme.accentAlt
    property bool selected: false

    signal activated()

    implicitWidth: 14
    implicitHeight: 14

    // Brilho quando selecionado
    Shape {
        anchors.centerIn: parent
        width: 22
        height: 22
        opacity: root.selected ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ShapePath {
            strokeColor: "transparent"

            fillGradient: RadialGradient {
                centerX: 11
                centerY: 11
                centerRadius: 11
                focalX: 11
                focalY: 11

                GradientStop {
                    position: 0.0
                    color: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.8)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.45)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.0)
                }
            }

            PathAngleArc {
                centerX: 11
                centerY: 11
                radiusX: 11
                radiusY: 11
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // Círculo
    Rectangle {
        id: circle

        anchors.centerIn: parent
        width: 14
        height: 14
        radius: 7
        color: root.dotColor
        opacity: root.enabled ? 1 : 0.4
        scale: circleArea.containsMouse ? 1.15 : 1

        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: circleArea
        anchors.fill: parent
        anchors.margins: -2
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
