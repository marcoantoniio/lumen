// Control Center (aberto pela bolinha do meio da ilha), no layout da referência:
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
import QtQuick
import QtQuick.Layouts

PopupWindow {
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

    anchor.window: panelWindow
    anchor.rect.x: anchorItem
                   ? anchorItem.x + (anchorItem.width - panelWidth) / 2
                   : (panelWindow ? panelWindow.width - panelWidth - Theme.barMargin : 0)
    anchor.rect.y: anchorItem
                   ? anchorItem.y + anchorItem.height - 1
                   : (panelWindow ? panelWindow.height + Theme.barMargin : 0)
    implicitWidth: panelWidth
    implicitHeight: 410
    color: "transparent"
    visible: ControlCenter.open

    onVisibleChanged: {
        if (!visible && ControlCenter.open)
            ControlCenter.open = false;
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

    // ---- notas (persistidas no stateDir do shell) ----
    FileView {
        id: notesFile

        path: Quickshell.stateDir + "/notes.txt"

        onLoadedChanged: {
            if (loaded)
                notesEdit.text = text();
        }
    }

    Timer {
        id: notesSave
        interval: 700
        onTriggered: notesFile.setText(notesEdit.text)
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

    Component.onCompleted: Clipboard.refresh()

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitHeight: column.implicitHeight + 32
        radius: Theme.radius
        topLeftRadius: 0
        topRightRadius: 0
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

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
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: ControlCenter.tab

                // ================= PAGE 0: CONTROL CENTER =================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

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
                            onActivated: Quickshell.execDetached(["spectacle", "-R", "s"])
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
            }

                // ================= PAGE 1: DASHBOARD =================
                // Saudação + layout da referência: Calendário | Clima | Sistema
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: Greeting.text
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
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
                    Layout.fillWidth: true
                    spacing: 8

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
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Clipboard.copyItem(modelData)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: Clipboard.items.length === 0
                        text: Clipboard.available
                              ? "Nenhum item no histórico"
                              : "Histórico indisponível (Klipper não encontrado)"
                        color: Theme.foregroundDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Text {
                    text: "Notas"
                    color: Theme.foregroundDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: 80
                    radius: 10
                    color: Theme.card

                    TextEdit {
                        id: notesEdit
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        color: Theme.foreground
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.background
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        onTextChanged: notesSave.restart()
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
                    glyph: "\u{F01E7}" // globo/navegador
                    onActivated: Quickshell.execDetached(["xdg-open", "https://duckduckgo.com"])
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
