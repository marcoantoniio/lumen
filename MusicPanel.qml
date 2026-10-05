// Painel de música — abre ao passar o mouse na ilha quando há música tocando.
// Capa com brilho da cor do álbum, controles, progresso (seek), saída de áudio,
// mixer por aplicativo, playlist (fila do álbum) e letras (lrclib).

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
    // Altura fixa: redimensionar a janela ao abrir/fechar seções glicha no
    // Wayland (o hover se perde e o painel some). Reserva o espaço das seções.
    implicitHeight: 352
    color: "transparent"
    visible: Music.panelOpen && !ControlCenter.open && !Notifications.centerOpen

    onVisibleChanged: {
        // Qt.callLater evita binding loop no visible (bug de flicker)
        if (!visible && Music.panelOpen)
            Qt.callLater(() => Music.panelOpen = false);
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

    component SectionButton: Rectangle {
        id: sectionButton

        property string glyph: ""
        property bool active: false

        signal activated()

        implicitWidth: 30
        implicitHeight: 30
        radius: 9
        color: sectionButton.active
               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
               : (sectionArea.containsMouse ? Theme.surfaceHover : "transparent")
        border.width: 1
        border.color: sectionButton.active ? Theme.accent
                    : (sectionArea.containsMouse ? Theme.border : "transparent")

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: sectionButton.glyph
            color: sectionButton.active ? Theme.accent : Theme.foreground
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        MouseArea {
            id: sectionArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sectionButton.activated()
        }
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

        // Hover do painel (precisa estar num Item; no PopupWindow não funciona)
        HoverHandler {
            onHoveredChanged: {
                Music.panelHovered = hovered;
                if (!hovered)
                    closeTimer.restart();
            }
        }

        width: parent.width
        height: column.height + 24
        implicitHeight: column.height + 24
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
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            height: implicitHeight
            spacing: 8

            // ---- cabeçalho: capa com brilho + infos ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    implicitWidth: 80
                    implicitHeight: 80

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
                        width: 80
                        height: 80
                        radius: 12
                        color: Theme.surfaceHover
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: Music.artUrl
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

            // ---- controles (ícones das seções em volta, na mesma linha) ----
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                spacing: 4

                // mixer: ícone vira alto-falante e o slider aparece ao lado
                SectionButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: Music.section === 1 ? "\u{F057E}" : "\u{F066A}" // volume-high / tune (mixer)
                    active: Music.section === 1
                    onActivated: Music.section = Music.section === 1 ? -1 : 1
                }

                LevelSlider {
                    id: mixSlider

                    Layout.alignment: Qt.AlignVCenter
                    // Uma única animação (0..1) guia largura, opacidade e visibilidade
                    property real openness: Music.section === 1 ? 1 : 0
                    // 84px: precisa caber nos 396px úteis da linha com os 4 botões
                    // de seção. Se estourar, o layout cresce e arrasta a barra de
                    // progresso junto.
                    Layout.preferredWidth: 84 * openness
                    visible: openness > 0.01
                    opacity: openness
                    value: Music.player && Music.player.volumeSupported ? Music.player.volume : 0
                    onMoved: (v) => {
                        if (Music.player && Music.player.volumeSupported)
                            Music.player.volume = v;
                    }

                    Behavior on openness {
                        NumberAnimation { duration: 260; easing.type: Easing.InOutCubic }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 26 * mixSlider.openness
                    visible: mixSlider.openness > 0.01
                    opacity: mixSlider.openness
                    text: Music.player && Music.player.volumeSupported
                          ? Math.round(Music.player.volume * 100) + "%" : ""
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Item { Layout.fillWidth: true }

                ControlButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: "\u{F04AE}" // nf-md-skip_previous
                    glyphSize: 19
                    onActivated: if (Music.canPrev) Music.player.previous()
                }

                ControlButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: Music.playing ? "\u{F03E4}" : "\u{F040A}" // pause / play
                    buttonSize: 46
                    glyphSize: 21
                    onActivated: if (Music.canToggle) Music.player.togglePlaying()
                }

                ControlButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: "\u{F04AD}" // nf-md-skip_next
                    glyphSize: 19
                    onActivated: if (Music.canNext) Music.player.next()
                }

                Item { Layout.fillWidth: true }

                // saída e letras à direita do player
                SectionButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: "\u{F04C3}" // nf-md-speaker (saída)
                    active: Music.section === 0
                    onActivated: Music.section = Music.section === 0 ? -1 : 0
                }

                SectionButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: "\u{F021A}" // nf-md-text_box (letras)
                    active: Music.section === 2
                    onActivated: Music.section = Music.section === 2 ? -1 : 2
                }

                SectionButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: "\u{F0CB8}" // nf-md-playlist_music (playlist/fila)
                    active: Music.section === 3
                    onActivated: Music.section = Music.section === 3 ? -1 : 3
                }
            }

            // ---- saída de áudio ----
            ColumnLayout {
                visible: Music.section === 0

                Layout.fillWidth: true
                Layout.preferredHeight: 114
                spacing: 4

                Text {
                    text: "Saída"
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 96

                    Flow {
                        id: deviceFlow

                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: panel.sinks

                            delegate: Rectangle {
                                id: deviceChip

                                required property var modelData

                                readonly property bool current: Pipewire.defaultAudioSink === modelData

                                implicitWidth: deviceRow.implicitWidth + 24
                                implicitHeight: 26
                                radius: 13
                                color: deviceChip.current
                                       ? Theme.accent
                                       : (deviceArea.containsMouse
                                          ? Qt.lighter(Theme.surfaceHover, 1.35)
                                          : Theme.surfaceHover)
                                border.width: 1
                                border.color: deviceChip.current
                                              ? Theme.accent
                                              : (deviceArea.containsMouse ? Theme.border : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: 120 }
                                }

                                Row {
                                    id: deviceRow

                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: deviceChip.current
                                        text: "\u{F012C}" // check
                                        color: Theme.accentInk
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        id: deviceLabel

                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, 300)
                                        text: modelData.description !== "" ? modelData.description : modelData.name
                                        color: deviceChip.current ? Theme.accentInk : Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: deviceChip.current ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: deviceArea

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }
                        }
                    }
                }
            }

            // ---- letras ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 127
                spacing: 4
                visible: Music.section === 2

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
                    Layout.preferredHeight: Math.min(105, lyricsCol.implicitHeight)
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

            // ---- playlist/fila (álbum da faixa atual) ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 127
                spacing: 4
                visible: Music.section === 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: Music.queueSourceKind === "playlist"
                              ? "Playlist · " + Music.queueSourceTitle
                              : (Music.queueSourceKind === "album"
                                 ? "Álbum · " + Music.queueSourceTitle
                                 : "Playlist")
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: Music.queueLoading
                        text: "carregando…"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        visible: !Music.queueLoading && Music.queueStatus === "error"
                        text: "não consegui carregar"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        visible: !Music.queueLoading && Music.queueStatus === "notrack"
                        text: "sem fila neste player"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Flickable {
                    id: queueFlick

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(105, queueCol.implicitHeight)
                    contentHeight: queueCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height

                    Behavior on contentY {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    // centraliza a faixa atual na lista
                    function scrollToCurrent() {
                        if (!visible || Music.queueIndex < 0)
                            return;
                        const item = queueCol.children[Music.queueIndex];
                        if (item)
                            queueFlick.contentY = Math.max(0, Math.min(
                                queueFlick.contentHeight - queueFlick.height,
                                item.y - queueFlick.height / 2 + item.height / 2));
                    }

                    onHeightChanged: scrollToCurrent()
                    onVisibleChanged: if (visible) scrollToCurrent()

                    Connections {
                        target: Music

                        function onQueueIndexChanged() { queueFlick.scrollToCurrent() }
                    }

                    Column {
                        id: queueCol

                        width: queueFlick.width
                        spacing: 2

                        Repeater {
                            model: Music.queueTracks

                            delegate: Rectangle {
                                id: queueRow

                                required property var modelData
                                required property int index

                                readonly property bool current: index === Music.queueIndex
                                readonly property bool played: Music.queueIndex >= 0 && index < Music.queueIndex

                                width: queueCol.width
                                height: 22
                                radius: 6
                                color: queueRow.current
                                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                       : (queueArea.containsMouse ? Theme.surfaceHover : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Text {
                                    id: queueNumber

                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    horizontalAlignment: Text.AlignRight
                                    text: queueRow.index + 1
                                    color: queueRow.current ? Theme.accent : Theme.foregroundDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: queueRow.current
                                }

                                Text {
                                    anchors.left: queueNumber.right
                                    anchors.leftMargin: 8
                                    anchors.right: queueDuration.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: queueRow.modelData.title
                                    color: queueRow.current ? Theme.accent
                                         : (queueRow.played ? Theme.foregroundDim : Theme.foreground)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: queueRow.current
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: queueDuration

                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: panel.formatTime(queueRow.modelData.duration)
                                    color: queueRow.current ? Theme.accent : Theme.foregroundDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: queueArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Music.playQueueTrack(queueRow.modelData.url)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
