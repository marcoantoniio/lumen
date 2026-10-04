// Painel de música — abre ao passar o mouse na ilha quando há música tocando.
// Capa com brilho da cor do álbum, controles, progresso (seek), saída de áudio,
// mixer por aplicativo e letras (lrclib).

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

PopupWindow {
    id: panel

    property var panelWindow: null
    property var anchorItem: null

    readonly property int panelWidth: Theme.musicPanelWidth

    readonly property var sinks: {
        const out = [];
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; ++i) {
            const n = nodes[i];
            if (!n.isStream && n.audio !== null && n.isSink)
                out.push(n);
        }
        return out;
    }

    anchor.window: panelWindow
    anchor.rect.x: anchorItem
                   ? anchorItem.x + (anchorItem.width - panelWidth) / 2
                   : (panelWindow ? panelWindow.width - panelWidth - Theme.barMargin : 0)
    anchor.rect.y: anchorItem
                   ? anchorItem.y + anchorItem.height - 1
                   : (panelWindow ? panelWindow.height + Theme.barMargin : 0)
    implicitWidth: panelWidth
    implicitHeight: Math.min(620, frame.implicitHeight)
    color: "transparent"
    visible: Music.panelOpen && Music.active && !ControlCenter.open && !Notifications.centerOpen

    onVisibleChanged: {
        // Qt.callLater evita binding loop no visible (bug de flicker)
        if (!visible && Music.panelOpen)
            Qt.callLater(() => Music.panelOpen = false);
    }

    HoverHandler {
        onHoveredChanged: {
            Music.panelHovered = hovered;
            if (!hovered)
                closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 350
        onTriggered: if (!Music.panelHovered) Music.panelOpen = false
    }

    function formatTime(seconds) {
        const t = Math.max(0, Math.floor(seconds));
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0");
    }

    // Cor dominante (mais viva) da capa, para o brilho
    ColorQuantizer {
        id: quant

        source: Music.artFile
        depth: 2
        rescaleSize: 64
    }

    readonly property color albumColor: {
        let best = Theme.accent;
        let bestScore = -1;
        for (let i = 0; i < quant.colors.length; ++i) {
            const c = quant.colors[i];
            const mx = Math.max(c.r, c.g, c.b);
            const mn = Math.min(c.r, c.g, c.b);
            const sat = mx <= 0 ? 0 : (mx - mn) / mx;
            const score = sat * (0.35 + 0.65 * mx);
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }
        return best;
    }

    component ControlButton: Rectangle {
        id: button

        property string glyph: ""
        property int buttonSize: 38
        property int glyphSize: 17

        signal activated()

        width: buttonSize
        height: buttonSize
        radius: buttonSize / 2
        color: buttonArea.containsMouse ? Theme.surfaceHover : "transparent"
        border.width: 1
        border.color: buttonArea.containsMouse ? Theme.border : "transparent"

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: Theme.foreground
            font.family: Theme.iconFont
            font.pixelSize: button.glyphSize
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitHeight: column.implicitHeight + 24
        radius: Theme.radius
        topLeftRadius: 0
        topRightRadius: 0
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        opacity: panel.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        // Junção com a ilha: esconde a borda de cima
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 1
                rightMargin: 1
            }
            height: 1
            color: "#000000"
        }

        ColumnLayout {
            id: column

            anchors {
                fill: parent
                margins: 12
            }
            spacing: 10

            // ---- cabeçalho: capa com brilho + infos ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 96

                    // brilho na cor do álbum
                    Shape {
                        anchors.centerIn: parent
                        width: 210
                        height: 210
                        opacity: 0.9

                        ShapePath {
                            strokeColor: "transparent"

                            fillGradient: RadialGradient {
                                centerX: 105
                                centerY: 105
                                centerRadius: 105
                                focalX: 105
                                focalY: 105

                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(panel.albumColor.r, panel.albumColor.g, panel.albumColor.b, 0.75)
                                }
                                GradientStop {
                                    position: 0.42
                                    color: Qt.rgba(panel.albumColor.r, panel.albumColor.g, panel.albumColor.b, 0.4)
                                }
                                GradientStop {
                                    position: 0.75
                                    color: Qt.rgba(panel.albumColor.r, panel.albumColor.g, panel.albumColor.b, 0.12)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Qt.rgba(panel.albumColor.r, panel.albumColor.g, panel.albumColor.b, 0.0)
                                }
                            }

                            PathAngleArc {
                                centerX: 105
                                centerY: 105
                                radiusX: 105
                                radiusY: 105
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 96
                        height: 96
                        radius: 14
                        color: Theme.surfaceHover
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: Music.artFile !== "" ? Music.artFile : Music.artUrl
                            sourceSize: Qt.size(192, 192)
                            smooth: true
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: Music.title !== "" ? Music.title : "—"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Music.artist
                        color: panel.albumColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Music.album
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            // ---- progresso ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: panel.formatTime(Music.livePosition)
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                LevelSlider {
                    Layout.fillWidth: true
                    value: Music.progress
                    accent: panel.albumColor
                    onMoved: (v) => Music.seekTo(v)
                }

                Text {
                    text: panel.formatTime(Music.length)
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            // ---- controles ----
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                ControlButton {
                    glyph: "\u{F04AE}" // nf-md-skip_previous
                    glyphSize: 19
                    onActivated: if (Music.canPrev) Music.player.previous()
                }

                ControlButton {
                    glyph: Music.playing ? "\u{F03E4}" : "\u{F040A}" // pause / play
                    buttonSize: 46
                    glyphSize: 21
                    onActivated: if (Music.canToggle) Music.player.togglePlaying()
                }

                ControlButton {
                    glyph: "\u{F04AD}" // nf-md-skip_next
                    glyphSize: 19
                    onActivated: if (Music.canNext) Music.player.next()
                }
            }

            // ---- saída de áudio ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Saída"
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: deviceFlow.implicitHeight

                    Flow {
                        id: deviceFlow

                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: panel.sinks

                            delegate: Rectangle {
                                required property var modelData

                                readonly property bool current: Pipewire.defaultAudioSink === modelData

                                implicitWidth: deviceLabel.implicitWidth + 22
                                implicitHeight: 24
                                radius: 12
                                color: current
                                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                       : Theme.surfaceHover
                                border.width: 1
                                border.color: current ? Theme.accent : "transparent"

                                Text {
                                    id: deviceLabel

                                    anchors.centerIn: parent
                                    text: modelData.description !== "" ? modelData.description : modelData.name
                                    color: current ? Theme.accent : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }
                        }
                    }
                }
            }

            // ---- mixer (aplicativos) ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: Audio.streams.length > 0

                Text {
                    text: "Mixer"
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(streamCol.implicitHeight, 84)
                    contentHeight: streamCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: streamCol

                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: Audio.streams

                            delegate: RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    source: Audio.streamIcon(modelData)
                                    sourceSize: Qt.size(16, 16)
                                    smooth: true
                                    visible: source !== ""
                                }

                                Text {
                                    Layout.preferredWidth: 86
                                    text: Audio.streamName(modelData)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                                LevelSlider {
                                    Layout.fillWidth: true
                                    value: modelData.audio ? modelData.audio.volume : 0
                                    muted: modelData.audio ? modelData.audio.muted : false
                                    onMoved: (v) => {
                                        if (modelData.audio)
                                            modelData.audio.volume = v;
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 30
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
                                    color: Theme.foregroundDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: modelData.audio && modelData.audio.muted ? "\u{F0581}" : "\u{F057E}"
                                    color: modelData.audio && modelData.audio.muted ? Theme.foregroundDim : Theme.foreground
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- letras ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Letras"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: Music.lyricsLoading
                        text: "carregando…"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        visible: !Music.lyricsLoading && Music.lyricsStatus === "notfound"
                        text: "não encontrada"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Flickable {
                    id: lyricsFlick

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(130, lyricsCol.implicitHeight)
                    contentHeight: lyricsCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height

                    Behavior on contentY {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    // rola para a linha atual (letras sincronizadas)
                    onContentYChanged: scrollTarget = -1
                    property real scrollTarget: -1

                    Column {
                        id: lyricsCol

                        width: lyricsFlick.width
                        spacing: 2

                        // sincronizada: linha atual destacada
                        Repeater {
                            model: Music.lyricsSynced ? Music.lyricsLines : []

                            delegate: Text {
                                required property var modelData
                                required property int index

                                width: lyricsCol.width
                                text: modelData.text
                                color: index === Music.currentLyricIndex ? Theme.accent : Theme.foregroundDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: index === Music.currentLyricIndex
                                wrapMode: Text.WordWrap

                                Behavior on color {
                                    ColorAnimation { duration: 180 }
                                }
                            }
                        }

                        // simples
                        Text {
                            visible: !Music.lyricsSynced && Music.lyricsText !== ""
                            width: lyricsCol.width
                            text: Music.lyricsText
                            color: Theme.foregroundDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    // acompanha a linha atual
                    Connections {
                        target: Music

                        function onCurrentLyricIndexChanged() {
                            if (!Music.lyricsSynced || Music.currentLyricIndex < 0)
                                return;
                            const item = lyricsCol.children[Music.currentLyricIndex];
                            if (item)
                                lyricsFlick.contentY = Math.max(0, Math.min(
                                    lyricsFlick.contentHeight - lyricsFlick.height,
                                    item.y - lyricsFlick.height / 2 + item.height / 2));
                        }
                    }
                }
            }
        }
    }
}
