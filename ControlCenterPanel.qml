// Control Center (aberto pela bolinha do meio da ilha), em 3 colunas:
// - Abas: Control Center | Dashboard | Clipboard & Notes
// - Control Center em duas colunas:
//   - Esquerda: "Quick Settings" (rede, DND, night light, caffeine, bluetooth,
//     gravador) + "Sessão" (bloquear, sair, reiniciar, desligar)
//   - Direita: "Levels" (saída, microfone, brilho) + mídia

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: panel

    property var panelWindow: null
    property var anchorItem: null

    property string cpuText: "—"
    property real cpuProgress: -1
    property string memText: "—"
    property real memProgress: -1
    property string gpuText: "—"
    property string gpuLabel: "GPU"
    property real gpuProgress: -1
    property string tempText: "—"
    property var disks: []
    property string uptimeText: "—"

    // Menu de dispositivos de áudio (setinha das linhas de nível)
    property bool deviceMenuOpen: false
    property string deviceMenuKind: "sink"
    property var deviceMenuAnchor: null

    // reflete no singleton (o timer de fechamento da barra consulta)
    onDeviceMenuOpenChanged: ControlCenter.deviceMenuOpen = deviceMenuOpen

    // Métricas para o card "Sistema" (3ª coluna do Dashboard)
    readonly property var sysMetrics: {
        const out = [];
        out.push({ label: "CPU", value: panel.cpuText, progress: panel.cpuProgress });
        out.push({ label: "RAM", value: panel.memText, progress: panel.memProgress });
        out.push({ label: "GPU", value: panel.gpuText, progress: panel.gpuProgress });
        const t = parseFloat(panel.tempText);
        out.push({ label: "Temp", value: panel.tempText, progress: isFinite(t) ? t / 100 : -1 });
        for (let i = 0; i < panel.disks.length; ++i) {
            const d = panel.disks[i];
            if (d.label === "/")
                out.push({ label: "root", value: d.percent, progress: d.progress });
        }
        out.push({ label: "Uptime", value: panel.uptimeText, progress: -1 });
        return out;
    }

    property real prevCpuTotal: -1
    property real prevCpuIdle: -1

    // Nomes amigáveis dos discos — ajuste para os seus pontos de montagem
    function diskName(mount) {
        if (mount === "/")
            return "root";
        if (mount === "/mnt/ssd")
            return "jogos";
        if (mount === "/mnt/hd")
            return "HD";
        return mount;
    }

    function parseSys(out) {
        const lines = out.split("\n").filter(l => l.trim().length > 0);
        const data = ({});

        for (let i = 0; i < lines.length; ++i) {
            const sp = lines[i].indexOf(" ");
            if (sp > 0)
                data[lines[i].slice(0, sp)] = lines[i].slice(sp + 1);
        }

        // CPU (delta entre amostras de /proc/stat)
        if (data.cpu !== undefined) {
            const f = data.cpu.trim().split(/\s+/).slice(1).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = (f[3] || 0) + (f[4] || 0);
            if (prevCpuTotal > 0 && total > prevCpuTotal) {
                const dt = total - prevCpuTotal;
                const di = idle - prevCpuIdle;
                const busy = Math.max(0, Math.min(1, 1 - di / dt));
                cpuText = Math.round(busy * 100) + "%";
                cpuProgress = busy;
            }
            prevCpuTotal = total;
            prevCpuIdle = idle;
        }

        // Memória
        if (data.mem !== undefined) {
            const f = data.mem.trim().split(/\s+/);
            const total = Number(f[1]);
            const used = Number(f[2]);
            if (total > 0) {
                memText = Math.round(used / total * 100) + "%";
                memProgress = used / total;
            }
        }

        // GPU (nvidia-smi: utilização, VRAM usada, VRAM total em MiB)
        if (data.gpu !== undefined && /^\d/.test(data.gpu.trim())) {
            const f = data.gpu.split(",").map(s => Number(s.trim()));
            if (f.length >= 3 && isFinite(f[0])) {
                gpuText = f[0] + "%";
                gpuProgress = f[0] / 100;
                gpuLabel = "GPU · " + (f[1] / 1024).toFixed(1) + "/" + (f[2] / 1024).toFixed(0) + " GB";
            }
        }

        // Temperatura da CPU
        if (data.temp !== undefined) {
            const m = data.temp.match(/\+([0-9.]+)°C/);
            if (m)
                tempText = Math.round(Number(m[1])) + "°C";
        }

        // Discos (3 maiores filesystems reais)
        if (data.disks !== undefined) {
            const entries = data.disks.split("|").filter(s => s.trim().length > 0);
            const out = [];
            for (let i = 0; i < entries.length; ++i) {
                const f = entries[i].trim().split(/\s+/);
                if (f.length >= 3) {
                    const size = Number(f[1]);
                    const used = Number(f[2]);
                    if (size > 0)
                        out.push({ label: f[0], percent: Math.round(used / size * 100) + "%", progress: used / size });
                }
            }
            disks = out;
        }

        // Uptime
        if (data.uptime !== undefined) {
            const secs = Number(data.uptime.trim().split(/\s+/)[0]);
            if (isFinite(secs)) {
                const d = Math.floor(secs / 86400);
                const h = Math.floor((secs % 86400) / 3600);
                const m = Math.floor((secs % 3600) / 60);
                uptimeText = (d > 0 ? d + "d " : "") + h + "h " + m + "min";
            }
        }
    }

    readonly property int panelWidth: Theme.controlCenterPanelWidth
    // Largura exata de cada coluna do Control Center (margens 16*2 + spacing 18)
    readonly property real controlColumnWidth: (panelWidth - 32 - 18) / 2

    // Layer surface em vez de popup: popups não recebem teclado no KWin; a
    // layer surface com foco sob demanda recebe (necessário para as notas).
    screen: panelWindow ? panelWindow.screen : null
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        // encosta na ilha (fundo da pílula - 1)
        top: Island.square ? 38 : 45
    }
    // Altura fixa: redimensionar a janela ao trocar de aba glicha no Wayland
    implicitHeight: 464
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Só o cartão recebe cliques (o resto da faixa é click-through)
    mask: Region { item: frame }
    visible: ControlCenter.open

    onVisibleChanged: {
        // Qt.callLater evita binding loop no visible (bug de flicker)
        if (!visible && ControlCenter.open)
            Qt.callLater(() => ControlCenter.open = false);
        if (visible)
            Brightness.refresh();
    }

    // Vincula os nós de áudio para poder ler/escrever volume e mute
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var player: {
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; ++i) {
            if (players[i].isPlaying)
                return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }

    // Animação de troca de aba: fade + zoom leve na página nova
    property int _lastTab: 0
    property Item _animItem: null

    // dir: 1 = aba à direita (conteúdo desliza para a direita), -1 = esquerda
    function animatePage(dir) {
        const item = pages.itemAt(ControlCenter.tab);
        if (!item)
            return;
        panel._animItem = item;
        item.opacity = 0;
        item.scale = 0.98;
        item.shiftX = -dir * 42;
        fadeIn.restart();
        popIn.restart();
        slideIn.restart();
    }

    NumberAnimation {
        id: fadeIn

        target: panel._animItem
        property: "opacity"
        to: 1
        duration: 170
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: popIn

        target: panel._animItem
        property: "scale"
        to: 1
        duration: 170
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideIn

        target: panel._animItem
        property: "shiftX"
        to: 0
        duration: 200
        easing.type: Easing.OutCubic
    }

    Connections {
        target: ControlCenter

        function onTabChanged() {
            const dir = ControlCenter.tab > panel._lastTab ? 1 : -1;
            panel._lastTab = ControlCenter.tab;
            panel.animatePage(dir);
        }
    }

    // ---- dashboard ----
    Process {
        id: sysProc

        command: ["sh", "-c",
            "echo \"cpu $(head -1 /proc/stat)\"; " +
            "echo \"mem $(free -b | sed -n 2p)\"; " +
            "echo \"gpu $(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)\"; " +
            "echo \"temp $(sensors 2>/dev/null | grep -m1 -E 'Package id 0|Tctl|Tdie')\"; " +
            "echo \"disks $(df -B1 -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs -x fuse.portal --output=source,target,size,used 2>/dev/null | tail -n +2 | awk '!seen[$1]++ { print $2, $3, $4 }' | sort -k2 -n -r | head -3 | paste -sd'|' -)\"; " +
            "echo \"uptime $(cat /proc/uptime)\""
        ]
        stdout: StdioCollector {
            onStreamFinished: panel.parseSys(text)
        }
    }

    Timer {
        interval: 1500
        running: panel.visible && ControlCenter.tab === 1
        repeat: true
        onTriggered: sysProc.running = true
    }

    // ---- notas: carrega a nota atual nos campos (título + corpo) ----
    function loadCurrentNote() {
        const n = Notes.notes[Notes.current];
        notesTitle.text = n ? (n.title || "") : "";
        notesEdit.text = n ? (n.body || "") : "";
    }

    Connections {
        target: Notes

        function onCurrentChanged() { panel.loadCurrentNote(); }
        function onLoadSeqChanged() { panel.loadCurrentNote(); }
    }

    // ---- histórico do clipboard (Klipper) + refresh por aba ----
    Connections {
        target: ControlCenter

        function onTabChanged() {
            if (ControlCenter.tab === 0)
                Brightness.refresh();
            if (ControlCenter.tab === 1)
                sysProc.running = true;
            if (ControlCenter.tab === 2)
                Clipboard.refresh();
        }
    }

    Timer {
        interval: 3000
        running: panel.visible && ControlCenter.tab === 2
        repeat: true
        onTriggered: Clipboard.refresh()
    }

    Component.onCompleted: {
        sysProc.running = true;
        Clipboard.refresh();
        panel.loadCurrentNote();
    }

    Rectangle {
        id: frame

        width: panel.panelWidth
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        radius: Theme.radius
        topLeftRadius: 0
        topRightRadius: 0
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        HoverHandler {
            onHoveredChanged: ControlCenter.panelHovered = hovered
        }

        opacity: panel.visible ? 1 : 0
        scale: panel.visible ? 1 : 0.97

        // Junção com a ilha: esconde a borda de cima (sem linha divisória)
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

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: column

            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            // ---- abas + fechar ----
            RowLayout {
                id: tabBar
                Layout.fillWidth: true
                spacing: 8

                PanelTab {
                    label: "Control Center"
                    selected: ControlCenter.tab === 0
                    onActivated: ControlCenter.tab = 0
                }

                PanelTab {
                    label: "Dashboard"
                    selected: ControlCenter.tab === 1
                    onActivated: ControlCenter.tab = 1
                }

                PanelTab {
                    label: "Clipboard & Notes"
                    selected: ControlCenter.tab === 2
                    onActivated: ControlCenter.tab = 2
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.foreground : Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ControlCenter.open = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            // ================= PÁGINAS (StackLayout troca sem bug de altura) =================
            StackLayout {
                id: pages

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredHeight: currentPage ? currentPage.implicitHeight : 0
                currentIndex: ControlCenter.tab

                // ================= PAGE 0: CONTROL CENTER =================
                RowLayout {
                    id: ccPage

                    Layout.fillWidth: true
                    spacing: 18

                    property real shiftX: 0
                    transform: Translate { x: ccPage.shiftX }

                // -------- esquerda: Quick Settings + Sessão --------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: panel.controlColumnWidth
                    Layout.maximumWidth: panel.controlColumnWidth
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    Text {
                        text: "Quick Settings"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0201}" // nf-md-earth (rede)
                            label: "Rede"
                            active: Networking.connectivity === NetworkConnectivity.Full
                            onActivated: {
                                if (Networking.wifiHardwareEnabled)
                                    Networking.wifiEnabled = !Networking.wifiEnabled;
                            }
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F009B}" // nf-md-bell-off
                            label: "Não Perturbe"
                            active: Notifications.dnd
                            onActivated: Notifications.dnd = !Notifications.dnd
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0599}" // nf-md-brightness-6 (night light)
                            label: "Night Light"
                            available: ControlCenter.nightLightAvailable
                            active: ControlCenter.nightLightEnabled
                            onActivated: ControlCenter.toggleNightLight()
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0176}" // nf-md-coffee
                            label: "Caffeine"
                            active: ControlCenter.caffeineEnabled
                            onActivated: ControlCenter.caffeineEnabled = !ControlCenter.caffeineEnabled
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F00AF}" // nf-md-bluetooth
                            label: "Bluetooth"
                            available: Bluetooth.defaultAdapter !== null
                            active: Bluetooth.defaultAdapter !== null && Bluetooth.defaultAdapter.enabled
                            onActivated: {
                                if (Bluetooth.defaultAdapter !== null)
                                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                            }
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0100}" // nf-md-video
                            label: "Gravador"
                            active: Recorder.recording
                            onActivated: Recorder.toggle()
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F05A0}" // nf-md-webcam
                            label: "Câmera"
                            active: Webcam.open
                            onActivated: Webcam.toggle()
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0763}" // nf-md-square-outline
                            label: "Ilha quadrada"
                            active: Island.square
                            onActivated: Island.square = !Island.square
                        }
                    }

                    Text {
                        text: "Sessão"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F033E}" // nf-md-lock
                            label: "Bloquear"
                            onActivated: Quickshell.execDetached(["loginctl", "lock-session"])
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0343}" // nf-md-logout
                            label: "Sair"
                            onActivated: {
                                const sid = Quickshell.env("XDG_SESSION_ID");
                                if (sid)
                                    Quickshell.execDetached(["loginctl", "terminate-session", sid]);
                            }
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0709}" // nf-md-restart
                            label: "Reiniciar"
                            onActivated: Quickshell.execDetached(["systemctl", "reboot"])
                        }

                        QuickToggle {
                            Layout.fillWidth: true
                            glyph: "\u{F0425}" // nf-md-power
                            label: "Desligar"
                            onActivated: Quickshell.execDetached(["systemctl", "poweroff"])
                        }
                    }
                }

                // -------- direita: Levels + mídia --------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: panel.controlColumnWidth
                    Layout.maximumWidth: panel.controlColumnWidth
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    // ---- visões: níveis <-> mixer (transição animada) ----
                    Item {
                        id: mixViews

                        Layout.fillWidth: true
                        implicitHeight: Math.max(levelsView.implicitHeight, mixerView.implicitHeight)
                        clip: true

                        states: State {
                            name: "mixer"
                            when: ControlCenter.mixerOpen

                            PropertyChanges {
                                target: levelsView

                                opacity: 0
                                scale: 0.96
                                shiftX: -28
                            }

                            PropertyChanges {
                                target: mixerView

                                opacity: 1
                                scale: 1
                                shiftX: 0
                            }
                        }

                        transitions: [
                            // abrindo: níveis saem rápido à esquerda, mixer entra suave da direita
                            Transition {
                                from: ""
                                to: "mixer"

                                ParallelAnimation {
                                    NumberAnimation { target: levelsView; property: "opacity"; duration: 140; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: levelsView; property: "shiftX"; duration: 280; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: levelsView; property: "scale"; duration: 280; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: mixerView; property: "opacity"; duration: 220; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: mixerView; property: "shiftX"; duration: 280; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: mixerView; property: "scale"; duration: 280; easing.type: Easing.OutCubic }
                                }
                            },
                            // fechando: mixer sai rápido à direita, níveis voltam suave da esquerda
                            Transition {
                                from: "mixer"
                                to: ""

                                ParallelAnimation {
                                    NumberAnimation { target: mixerView; property: "opacity"; duration: 140; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: mixerView; property: "shiftX"; duration: 280; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: mixerView; property: "scale"; duration: 280; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: levelsView; property: "opacity"; duration: 220; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: levelsView; property: "shiftX"; duration: 280; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: levelsView; property: "scale"; duration: 280; easing.type: Easing.OutCubic }
                                }
                            }
                        ]

                        // ---- visão 0: níveis (saída/microfone/brilho) ----
                        ColumnLayout {
                            id: levelsView

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 8

                            property real shiftX: 0
                            transform: Translate { x: levelsView.shiftX }

                            opacity: 1
                            scale: 1
                            enabled: !ControlCenter.mixerOpen

                            Text {
                                text: "Levels"
                                color: Theme.foregroundDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            LevelRow {
                                id: sinkRow

                                Layout.fillWidth: true
                                glyph: panel.sink && panel.sink.audio && panel.sink.audio.muted ? "\u{F0581}" : "\u{F057E}" // volume-off / volume-high
                                title: "Saída · " + Math.round((panel.sink && panel.sink.audio ? panel.sink.audio.volume : 0) * 100) + "%"
                                subtitle: panel.sink ? (panel.sink.description || panel.sink.name) : "sem saída de áudio"
                                value: panel.sink && panel.sink.audio ? panel.sink.audio.volume : 0
                                muted: panel.sink && panel.sink.audio ? panel.sink.audio.muted : false
                                onMoved: (v) => {
                                    if (panel.sink && panel.sink.audio)
                                        panel.sink.audio.volume = v;
                                }
                                onIconClicked: {
                                    if (panel.sink && panel.sink.audio)
                                        panel.sink.audio.muted = !panel.sink.audio.muted;
                                }
                                onArrowClicked: {
                                    if (panel.deviceMenuOpen && panel.deviceMenuKind === "sink") {
                                        panel.deviceMenuOpen = false;
                                    } else {
                                        panel.deviceMenuAnchor = sinkRow.arrowItem;
                                        panel.deviceMenuKind = "sink";
                                        panel.deviceMenuOpen = true;
                                    }
                                }
                            }

                            LevelRow {
                                id: sourceRow

                                Layout.fillWidth: true
                                glyph: panel.source && panel.source.audio && panel.source.audio.muted ? "\u{F036D}" : "\u{F036C}" // mic-off / mic
                                title: "Microfone · " + Math.round((panel.source && panel.source.audio ? panel.source.audio.volume : 0) * 100) + "%"
                                subtitle: panel.source ? (panel.source.description || panel.source.name) : "sem microfone"
                                value: panel.source && panel.source.audio ? panel.source.audio.volume : 0
                                muted: panel.source && panel.source.audio ? panel.source.audio.muted : false
                                onMoved: (v) => {
                                    if (panel.source && panel.source.audio)
                                        panel.source.audio.volume = v;
                                }
                                onIconClicked: {
                                    if (panel.source && panel.source.audio)
                                        panel.source.audio.muted = !panel.source.audio.muted;
                                }
                                onArrowClicked: {
                                    if (panel.deviceMenuOpen && panel.deviceMenuKind === "source") {
                                        panel.deviceMenuOpen = false;
                                    } else {
                                        panel.deviceMenuAnchor = sourceRow.arrowItem;
                                        panel.deviceMenuKind = "source";
                                        panel.deviceMenuOpen = true;
                                    }
                                }
                            }

                            LevelRow {
                                Layout.fillWidth: true
                                glyph: "\u{F0599}" // nf-md-brightness-6
                                title: "Brilho · " + Brightness.value + "%"
                                subtitle: Brightness.available
                                          ? ("DDC/CI · " + Brightness.displayName)
                                          : "sem DDC/CI neste sistema"
                                value: Brightness.available ? Brightness.value / Brightness.maxValue : 0
                                available: Brightness.available
                                showArrow: false
                                onMoved: (v) => Brightness.setValue(v * Brightness.maxValue)
                            }

                            // mídia (só quando há player)
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                visible: panel.player !== null
                                spacing: 8

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: Theme.accentAlt

                                    Text {
                                        anchors.centerIn: parent
                                        text: panel.player !== null && panel.player.isPlaying ? "\u{F03E4}" : "\u{F040A}" // pause / play
                                        font.family: Theme.iconFont
                                        font.pixelSize: 15
                                        color: Theme.foreground
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (panel.player !== null && panel.player.canTogglePlaying)
                                                panel.player.togglePlaying();
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: panel.player !== null ? panel.player.identity : ""
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: panel.player !== null ? (panel.player.trackTitle || "—") : ""
                                        color: Theme.foregroundDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                        }

                        // ---- visão 1: mixer de aplicativos ----
                        ColumnLayout {
                            id: mixerView

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 8

                            property real shiftX: 28
                            transform: Translate { x: mixerView.shiftX }

                            opacity: 0
                            scale: 0.96
                            enabled: ControlCenter.mixerOpen

                            // ---- mixer de aplicativos (substitui os Levels) ----
                            Text {
                                Layout.fillWidth: true
                                text: "Aplicativos tocando som"
                                color: Theme.foregroundDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            Flickable {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(mixCol.implicitHeight, 240)
                                contentHeight: mixCol.implicitHeight
                                clip: true
                                interactive: contentHeight > height

                                Column {
                                    id: mixCol

                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: Audio.playbackStreams

                                        delegate: LevelRow {
                                            required property var modelData

                                            width: mixCol.width
                                            glyph: modelData.audio && modelData.audio.muted ? "\u{F0581}" : "\u{F057E}"
                                            title: Audio.streamName(modelData) + " · "
                                                   + Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%"
                                            subtitle: ""
                                            value: modelData.audio ? modelData.audio.volume : 0
                                            muted: modelData.audio ? modelData.audio.muted : false
                                            showArrow: false
                                            onMoved: (v) => {
                                                if (modelData.audio)
                                                    modelData.audio.volume = v;
                                            }
                                            onIconClicked: {
                                                if (modelData.audio)
                                                    modelData.audio.muted = !modelData.audio.muted;
                                            }
                                        }
                                    }

                                    Text {
                                        width: mixCol.width
                                        visible: Audio.playbackStreams.length === 0
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "nenhum aplicativo tocando som agora"
                                        color: Theme.foregroundDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }

                        }
                    }

                    // botão do mixer (embaixo da lista)
                    QuickToggle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        glyph: "\u{F066A}" // nf-md-tune (mixer)
                        label: "Mixer de aplicativos"
                        active: ControlCenter.mixerOpen
                        onActivated: ControlCenter.mixerOpen = !ControlCenter.mixerOpen
                    }
                }
            }

                // ================= PAGE 1: DASHBOARD =================
                // Saudação + Calendário | Clima | Sistema
                ColumnLayout {
                    id: dashPage

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    property real shiftX: 0
                    transform: Translate { x: dashPage.shiftX }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: Greeting.text
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }

                        SystemClock {
                            id: dashClock
                            precision: SystemClock.Minutes
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            visible: Music.playing
                            text: Qt.formatDateTime(dashClock.date, "ddd d MMM")
                            color: Theme.foregroundDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            visible: Music.playing
                            text: Qt.formatDateTime(dashClock.date, "HH:mm")
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        CalendarCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        WeatherCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        SystemCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            metrics: panel.sysMetrics
                        }
                    }
                }

                // ================= PAGE 2: CLIPBOARD & NOTES =================
                ColumnLayout {
                    id: clipPage

                    Layout.fillWidth: true
                    spacing: 8

                    property real shiftX: 0
                    transform: Translate { x: clipPage.shiftX }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Histórico"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: Clipboard.items.length > 0
                        text: "limpar"
                        color: clearClip.containsMouse ? Theme.foreground : Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11

                        MouseArea {
                            id: clearClip
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Clipboard.clearHistory()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 110
                    radius: 10
                    color: Theme.card
                    clip: true

                    ListView {
                        id: histList

                        anchors {
                            fill: parent
                            margins: 6
                        }
                        model: Clipboard.items
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: 400

                        delegate: Rectangle {
                            required property var modelData

                            width: ListView.view.width
                            height: 28
                            radius: 8
                            color: itemArea.containsMouse ? Theme.surfaceHover : "#1f1f1f"

                            Text {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                text: modelData
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton)
                                        Clipboard.removeItem(modelData);
                                    else
                                        Clipboard.copyItem(modelData);
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: Clipboard.items.length === 0
                        text: Clipboard.available
                              ? "Nenhum item no histórico"
                              : "Histórico indisponível — instale o wl-clipboard"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Notas"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    // seta esquerda (só quando tem nota escondida à esquerda)
                    Text {
                        visible: notesChips.contentX > 1
                        text: "‹"
                        color: chipLeft.containsMouse ? Theme.foreground : Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 14

                        MouseArea {
                            id: chipLeft
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notesChips.scrollBy(-1)
                        }
                    }

                    // abas das notas (roláveis)
                    Flickable {
                        id: notesChips

                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        contentWidth: chipsRow.implicitWidth
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        // rolagem até o fim: persegue o fim enquanto o chip novo é
                        // medido (a largura do conteúdo só cresce depois do clique)
                        property bool goToEnd: false

                        function scrollBy(dir) {
                            goToEnd = false;
                            contentX = Math.max(0, Math.min(contentWidth - width, contentX + dir * 120));
                        }

                        function scrollToEnd() {
                            goToEnd = true;
                            scrollToEndNow();
                            endSettle.restart();
                        }

                        function scrollToEndNow() {
                            contentX = Math.max(0, contentWidth - width);
                        }

                        onContentWidthChanged: {
                            if (goToEnd) {
                                scrollToEndNow();
                                endSettle.restart();
                            }
                        }
                        onWidthChanged: if (goToEnd) scrollToEndNow()
                        onMovementStarted: goToEnd = false

                        Timer {
                            id: endSettle

                            interval: 400
                            onTriggered: notesChips.goToEnd = false
                        }

                        Behavior on contentX {
                            enabled: !notesChips.moving && !notesChips.flicking
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        Row {
                            id: chipsRow

                            spacing: 4

                            Repeater {
                                model: Notes.notes

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    readonly property bool current: index === Notes.current

                                    width: Math.min(chipText.implicitWidth + 16, 120)
                                    height: 22
                                    radius: 11
                                    color: current
                                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                           : (chipArea.containsMouse ? Theme.surfaceHover : Theme.card)
                                    border.width: 1
                                    border.color: current ? Theme.accent : "transparent"

                                    Text {
                                        id: chipText

                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        text: modelData.title !== "" ? modelData.title : "Sem título"
                                        color: current ? Theme.accent : Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    MouseArea {
                                        id: chipArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notes.current = index
                                    }

                                    // ✕ (aparece com o mouse em cima) — apaga a nota
                                    Rectangle {
                                        id: chipDel

                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: delChipArea.containsMouse ? Theme.urgent : Theme.surfaceHover
                                        border.width: 1
                                        border.color: delChipArea.containsMouse ? Theme.urgent : Theme.border
                                        anchors {
                                            right: parent.right
                                            rightMargin: 4
                                            verticalCenter: parent.verticalCenter
                                        }
                                        opacity: (chipArea.containsMouse || delChipArea.containsMouse) ? 1 : 0
                                        visible: opacity > 0.01
                                        scale: delChipArea.containsMouse ? 1.15 : 1

                                        Behavior on opacity {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }
                                        Behavior on scale {
                                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                        }
                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        // ✕ desenhado (centralizado certinho)
                                        Item {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 6

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 6
                                                height: 1.4
                                                radius: 0.7
                                                rotation: 45
                                                color: delChipArea.containsMouse ? Theme.background : Theme.foregroundDim
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 6
                                                height: 1.4
                                                radius: 0.7
                                                rotation: -45
                                                color: delChipArea.containsMouse ? Theme.background : Theme.foregroundDim
                                            }
                                        }

                                        MouseArea {
                                            id: delChipArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Notes.removeNote(index)
                                        }
                                    }
                                }
                            }

                        }
                    }

                    // seta direita (só quando tem nota escondida à direita)
                    Text {
                        visible: notesChips.contentX < notesChips.contentWidth - notesChips.width - 6
                        text: "›"
                        color: chipRight.containsMouse ? Theme.foreground : Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 14

                        MouseArea {
                            id: chipRight
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notesChips.scrollBy(1)
                        }
                    }

                    // criar nova nota (sempre visível)
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: plusArea.containsMouse ? Theme.surfaceHover : Theme.card
                        border.width: 1
                        border.color: plusArea.containsMouse ? Theme.border : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: plusArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Notes.addNote();
                                notesChips.scrollToEnd();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: 80
                    radius: 10
                    color: Theme.card

                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            TextInput {
                                id: notesTitle

                                Layout.fillWidth: true
                                color: Theme.foreground
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.background
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                selectByMouse: true
                                clip: true
                                onTextChanged: Notes.update(notesTitle.text, notesEdit.text)

                                Text {
                                    anchors.fill: parent
                                    visible: notesTitle.text === ""
                                    text: "Título"
                                    color: Theme.foregroundDim
                                    font: notesTitle.font
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                        }

                        TextEdit {
                            id: notesEdit

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Theme.foreground
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.background
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            clip: true
                            onTextChanged: Notes.update(notesTitle.text, notesEdit.text)
                        }
                    }
                }

            }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                Item { Layout.fillWidth: true }

                FooterIcon {
                    glyph: "\u{F018D}" // nf-md-console (terminal)
                    onActivated: Quickshell.execDetached(["kitty"])
                }

                FooterIcon {
                    glyph: "\u{F024B}" // pasta/arquivos
                    onActivated: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME")])
                }

                FooterIcon {
                    glyph: "\u{F01E7}" // globo/navegador (SearXNG local)
                    onActivated: Quickshell.execDetached(["xdg-open", "https://localhost"])
                }

                FooterIcon {
                    glyph: "\u{F014D}" // prancheta (Clipboard & Notes)
                    onActivated: ControlCenter.tab = 2
                }

                FooterIcon {
                    glyph: "\u{F0493}" // engrenagem (configurações)
                    onActivated: Quickshell.execDetached(["systemsettings"])
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // Menu de seleção de dispositivos (aberto pela setinha das linhas de nível)
    DeviceMenu {
        id: deviceMenu

        panelRef: panel
        anchorTarget: panel.deviceMenuAnchor
        kind: panel.deviceMenuKind
        visible: panel.deviceMenuOpen && panel.deviceMenuAnchor !== null
        onDismissed: panel.deviceMenuOpen = false
    }
}
