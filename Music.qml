pragma Singleton

// Música (MPRIS): player ativo (prioriza o Deezer), capa baixada localmente,
// cor dominante do álbum (para o brilho), letras (lrclib.net) e estado do painel.
//
// IPC:
//   qs -c lumen ipc call music toggle|next|previous|status

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // ---------- player ativo ----------
    readonly property var player: {
        const players = Mpris.players.values;
        const isDeezer = (p) => p.identity.toLowerCase().indexOf("deezer") >= 0;
        for (let i = 0; i < players.length; ++i)
            if (players[i].isPlaying && isDeezer(players[i]))
                return players[i];
        for (let i = 0; i < players.length; ++i)
            if (players[i].isPlaying)
                return players[i];
        for (let i = 0; i < players.length; ++i)
            if (isDeezer(players[i]))
                return players[i];
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool active: player !== null
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property bool canSeek: player !== null && player.canSeek
    readonly property bool canNext: player !== null && player.canGoNext
    readonly property bool canPrev: player !== null && player.canGoPrevious
    readonly property bool canToggle: player !== null && player.canTogglePlaying

    // ---------- posição (interpolada para a barra ficar suave) ----------
    property real livePosition: 0

    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, livePosition / length)) : 0

    Timer {
        interval: 500
        repeat: true
        running: root.playing
        onTriggered: {
            if (root.livePosition < root.length)
                root.livePosition = Math.min(root.length, root.livePosition + 0.5);
        }
    }

    function seekTo(fraction) {
        if (!root.canSeek || root.length <= 0)
            return;
        root.player.position = Math.max(0, Math.min(1, fraction)) * root.length;
        root.livePosition = root.player.position;
    }

    // ---------- painel (abre no hover da ilha) ----------
    property bool panelOpen: false
    property bool panelHovered: false

    // ---------- capa (baixada localmente p/ o ColorQuantizer) ----------
    property string artFile: ""
    property int _artSeq: 0
    property string _pendingArt: ""

    Process {
        id: artProc

        onExited: (code) => {
            if (code === 0 && root._pendingArt !== "")
                root.artFile = "file://" + root._pendingArt;
            else
                root.artFile = root.artUrl; // fallback: usa a URL remota
        }
    }

    function fetchArt() {
        if (root.artUrl === "") {
            root.artFile = "";
            return;
        }
        root._artSeq += 1;
        root._pendingArt = Quickshell.stateDir + "/music_art_" + (root._artSeq % 2) + ".jpg";
        artProc.command = ["curl", "-sL", "--max-time", "15", "-o", root._pendingArt, root.artUrl];
        artProc.running = true;
    }

    // ---------- letras (lrclib.net) ----------
    property string lyricsText: ""
    property var lyricsLines: []
    property bool lyricsSynced: false
    property bool lyricsLoading: false
    property string lyricsStatus: "" // "", "ok", "notfound", "error"

    readonly property int currentLyricIndex: {
        if (!root.lyricsSynced || root.lyricsLines.length === 0)
            return -1;
        let idx = -1;
        for (let i = 0; i < root.lyricsLines.length; ++i) {
            if (root.lyricsLines[i].t >= 0 && root.lyricsLines[i].t <= root.livePosition + 0.3)
                idx = i;
        }
        return idx;
    }

    Process {
        id: lyricsProc

        stdout: StdioCollector {
            onStreamFinished: root.parseLyrics(text)
        }
    }

    function fetchLyrics() {
        if (root.title === "") {
            root.lyricsText = "";
            root.lyricsLines = [];
            root.lyricsStatus = "";
            return;
        }

        root.lyricsLoading = true;
        root.lyricsStatus = "";
        root._lyricsSearching = false;

        const args = "artist_name=" + encodeURIComponent(root.artist)
                   + "&track_name=" + encodeURIComponent(root.title)
                   + (root.album !== "" ? "&album_name=" + encodeURIComponent(root.album) : "");
        lyricsProc.command = ["curl", "-s", "--max-time", "12",
                              "-H", "User-Agent: lumen-shell",
                              "https://lrclib.net/api/get?" + args];
        lyricsProc.running = true;
    }

    property bool _lyricsSearching: false

    function fetchLyricsSearch() {
        root._lyricsSearching = true;
        const q = encodeURIComponent(root.artist + " " + root.title);
        lyricsProc.command = ["curl", "-s", "--max-time", "12",
                              "-H", "User-Agent: lumen-shell",
                              "https://lrclib.net/api/search?q=" + q];
        lyricsProc.running = true;
    }

    function applyLyrics(data) {
        if (data.syncedLyrics) {
            const lines = [];
            const parts = data.syncedLyrics.split("\n");
            for (let i = 0; i < parts.length; ++i) {
                const m = parts[i].match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
                if (m)
                    lines.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3] });
                else if (parts[i].trim() !== "")
                    lines.push({ t: -1, text: parts[i] });
            }
            root.lyricsLines = lines;
            root.lyricsSynced = true;
            root.lyricsText = "";
        } else {
            root.lyricsLines = [];
            root.lyricsSynced = false;
            root.lyricsText = data.plainLyrics;
        }
        root.lyricsStatus = "ok";
    }

    function setLyricsNotFound() {
        root.lyricsText = "";
        root.lyricsLines = [];
        root.lyricsSynced = false;
        root.lyricsStatus = "notfound";
    }

    function parseLyrics(text) {
        root.lyricsLoading = false;

        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            data = null;
        }

        // resposta de busca (lista): pega a primeira com letra sincronizada
        if (Array.isArray(data)) {
            let best = null;
            for (let i = 0; i < data.length; ++i) {
                if (data[i].syncedLyrics) {
                    best = data[i];
                    break;
                }
                if (data[i].plainLyrics && best === null)
                    best = data[i];
            }
            if (best)
                root.applyLyrics(best);
            else
                root.setLyricsNotFound();
            return;
        }

        // /api/get achou direto
        if (data && data.statusCode !== 404 && (data.plainLyrics || data.syncedLyrics)) {
            root.applyLyrics(data);
            return;
        }

        // não achou: tenta a busca
        if (!root._lyricsSearching) {
            root.lyricsLoading = true;
            root.fetchLyricsSearch();
            return;
        }

        root.setLyricsNotFound();
    }

    // ---------- troca de faixa ----------
    function refreshTrack() {
        root.livePosition = root.position;
        artDebounce.restart();
        lyricsDebounce.restart();
    }

    Timer {
        id: artDebounce
        interval: 500
        onTriggered: root.fetchArt()
    }

    Timer {
        id: lyricsDebounce
        interval: 700
        onTriggered: root.fetchLyrics()
    }

    Connections {
        target: root.player

        function onTargetChanged() { if (root.title !== "") root.refreshTrack(); }
        function onTrackTitleChanged() { root.refreshTrack(); }
        function onTrackArtistChanged() { root.refreshTrack(); }
        function onTrackArtUrlChanged() { root.refreshTrack(); }
        function onPositionChanged() { root.livePosition = root.position; }
    }

    Component.onCompleted: if (root.title !== "") root.refreshTrack()

    // ---------- IPC ----------
    IpcHandler {
        target: "music"

        function toggle(): void {
            if (root.canToggle) root.player.togglePlaying();
        }
        function next(): void {
            if (root.canNext) root.player.next();
        }
        function previous(): void {
            if (root.canPrev) root.player.previous();
        }
        function status(): string {
            if (!root.active) return "nenhum player";
            return root.artist + " - " + root.title + (root.playing ? " (tocando)" : " (pausado)");
        }
        function getLyricsStatus(): string { return root.lyricsStatus; }
    }
}
