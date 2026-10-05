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
        const wanted = (p) => {
            const id = p.identity.toLowerCase();
            return id.indexOf("deezer") >= 0 || id.indexOf("spotify") >= 0;
        };
        for (let i = 0; i < players.length; ++i)
            if (players[i].isPlaying && wanted(players[i]))
                return players[i];
        for (let i = 0; i < players.length; ++i)
            if (wanted(players[i]))
                return players[i];
        return null;
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
    // Seção aberta: -1 nenhuma, 0 saída, 1 mixer, 2 letras
    property int section: -1

    // ---------- capa (baixada localmente p/ o ColorQuantizer) ----------
    // Nome de arquivo único por capa (hash da URL): reutilizar o mesmo caminho
    // faz o cache do Qt exibir a imagem antiga. O arquivo local serve só ao
    // quantizador; a exibição usa a URL remota (sempre a da faixa atual).
    property string artFile: ""
    property string _wantArt: ""
    property string _artInFlight: ""

    function artPathFor(url) {
        let h = 5381;
        for (let i = 0; i < url.length; ++i)
            h = ((h << 5) + h + url.charCodeAt(i)) | 0;
        return Quickshell.stateDir + "/music_art_" + (h >>> 0).toString(16) + ".jpg";
    }

    Process {
        id: artProc

        onExited: (code) => {
            const url = root._artInFlight;
            root._artInFlight = "";
            if (url === "")
                return;
            if (url !== root._wantArt) {
                // trocou de faixa durante o download: baixa a nova
                root.startArtDownload();
            } else if (code === 0) {
                const path = root.artPathFor(url);
                root.artFile = "file://" + path;
                // mantém só a capa atual no diretório de estado
                Quickshell.execDetached(["sh", "-c",
                    "find '" + Quickshell.stateDir + "' -maxdepth 1 -name 'music_art_*.jpg' ! -name '"
                    + path.substring(path.lastIndexOf("/") + 1) + "' -delete"]);
            }
        }
    }

    function startArtDownload() {
        if (root._wantArt === "" || root._artInFlight !== "")
            return;
        root._artInFlight = root._wantArt;
        artProc.command = ["curl", "-sL", "--max-time", "15",
                           "-o", root.artPathFor(root._wantArt), root._wantArt];
        artProc.running = true;
    }

    function fetchArt() {
        root._wantArt = root.artUrl;
        if (root.artUrl === "") {
            root.artFile = "";
            return;
        }
        root.startArtDownload();
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

    // ---------- fila/playlist (faixas do álbum da faixa atual) ----------
    // O Deezer não expõe a fila via MPRIS; montamos a lista pela API pública
    // do álbum da faixa atual: anteriores = já tocaram, atual = highlight,
    // seguintes = vão tocar. Clicar toca no Deezer (OpenUri).
    property var queueTracks: []
    property int queueIndex: -1
    property bool queueLoading: false
    property string queueStatus: "" // "", "ok", "notrack", "error"
    property string _queueAlbumId: ""

    function currentTrackUrl() {
        const md = root.player ? root.player.metadata : null;
        return md && md["xesam:url"] ? String(md["xesam:url"]) : "";
    }

    function trackIdFromUrl(url) {
        const m = url.match(/track\/(\d+)/);
        return m ? m[1] : "";
    }

    function fetchQueue() {
        const id = root.trackIdFromUrl(root.currentTrackUrl());
        if (id === "") {
            root.queueTracks = [];
            root.queueIndex = -1;
            root._queueAlbumId = "";
            root.queueStatus = root.title === "" ? "" : "notrack";
            return;
        }
        root.queueLoading = true;
        root.queueStatus = "";
        queueTrackProc.command = ["curl", "-s", "--max-time", "10",
                                  "https://api.deezer.com/track/" + id];
        queueTrackProc.running = true;
    }

    function parseQueueTrack(text) {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            data = null;
        }
        const albumId = data && data.album && data.album.id ? String(data.album.id) : "";
        if (albumId === "") {
            root.queueLoading = false;
            root.queueTracks = [];
            root.queueIndex = -1;
            root.queueStatus = "error";
            return;
        }
        if (albumId === root._queueAlbumId) {
            root.queueLoading = false;
            root.updateQueueIndex();
            return;
        }
        root._queueAlbumId = albumId;
        queueAlbumProc.command = ["curl", "-s", "--max-time", "10",
                                  "https://api.deezer.com/album/" + albumId];
        queueAlbumProc.running = true;
    }

    function parseQueueAlbum(text) {
        root.queueLoading = false;
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            data = null;
        }
        const list = data && data.tracks && data.tracks.data ? data.tracks.data : null;
        if (!list) {
            root.queueTracks = [];
            root.queueIndex = -1;
            root.queueStatus = "error";
            return;
        }
        const out = [];
        for (let i = 0; i < list.length; ++i) {
            out.push({
                id: String(list[i].id),
                title: list[i].title || "",
                duration: list[i].duration || 0,
                url: "https://deezer.com/track/" + list[i].id
            });
        }
        root.queueTracks = out;
        root.queueStatus = "ok";
        root.updateQueueIndex();
    }

    function updateQueueIndex() {
        const id = root.trackIdFromUrl(root.currentTrackUrl());
        let idx = -1;
        for (let i = 0; i < root.queueTracks.length; ++i) {
            if (root.queueTracks[i].id === id) {
                idx = i;
                break;
            }
        }
        root.queueIndex = idx;
    }

    function playQueueTrack(url) {
        if (root.player && root.player.dbusName !== "")
            Quickshell.execDetached(["busctl", "--user", "call", root.player.dbusName,
                                     "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2",
                                     "OpenUri", "s", url]);
    }

    Process {
        id: queueTrackProc
        stdout: StdioCollector { onStreamFinished: root.parseQueueTrack(text) }
    }

    Process {
        id: queueAlbumProc
        stdout: StdioCollector { onStreamFinished: root.parseQueueAlbum(text) }
    }

    Timer {
        id: queueDebounce
        interval: 400
        onTriggered: root.fetchQueue()
    }

    onSectionChanged: if (section === 3 && queueTracks.length === 0 && title !== "") fetchQueue()

    // ---------- troca de faixa ----------
    function refreshTrack() {
        root.livePosition = root.position;
        artDebounce.restart();
        lyricsDebounce.restart();
        queueDebounce.restart();
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
        function getQueue(): string { return root.queueStatus + " " + root.queueIndex + "/" + root.queueTracks.length; }
        function section(n: int): void { root.section = n; }
        function panel(open: bool): void { root.panelOpen = open; }
    }
}
