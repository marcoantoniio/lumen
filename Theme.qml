pragma Singleton

// Tema central: cores, métricas e fontes.
// Mude tudo por aqui — nenhum componente tem cor hardcoded.

import Quickshell
import QtQuick

Singleton {
    // Cores (pílula preta com leve transparência + acentos quentes)
    // Formato Qt: #AARRGGBB — o AA controla a transparência (eb ≈ 92%)
    readonly property color background: "#eb000000"
    readonly property color surface: "#f0000000"
    readonly property color card: "#141414"
    readonly property color surfaceHover: "#2b2825"
    readonly property color foreground: "#efeceb"
    readonly property color foregroundDim: "#a09890"
    readonly property color accent: "#f4be9e"
    // Cor de conteúdo (ícones/texto) sobre o acento — o acento é claro, então escuro
    readonly property color accentInk: "#1f1a17"
    readonly property color accentAlt: "#e84070"
    readonly property color accentCool: "#40d8d8"
    readonly property color accentGreen: "#a6e3a1"
    readonly property color accentPurple: "#cba6f7"
    readonly property color urgent: "#e8836f"
    readonly property color recording: "#ff4b4b"
    readonly property color border: "#332f2c"

    // Métricas
    readonly property int barHeight: 40
    readonly property int barRadius: 20
    readonly property int barMargin: 6
    readonly property int pillPadding: 14
    readonly property int spacing: 8
    readonly property int radius: 14

    // Fontes (instaladas no sistema)
    readonly property string fontFamily: "Noto Sans"
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    // Larguras dos painéis (a ilha se adapta a elas quando abrem)
    readonly property int notificationPanelWidth: 380
    readonly property int controlCenterPanelWidth: 540
}
