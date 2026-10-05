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

    // ---------- fila/playlist (sua playlist + histórico real da sessão) ----------
    // O Deezer não expõe a fila via MPRIS. Montamos a lista assim:
    // - já tocadas: histórico real desta sessão (qualquer fonte, na ordem);
    // - atual: a faixa tocando (highlight);
    // - próximas: da última playlist sua detectada (a faixa atual ou a última
    //   tocada ancora a posição), sem repetir o que já tocou.
    // A playlist fica mesmo quando a faixa é recomendação (não pertence a
    // nenhuma playlist); só cai no álbum se nenhuma playlist foi detectada.
    // Clicar toca no Deezer (OpenUri).
    property var queueTracks: []
    property var queueRows: []
    property var playHistory: []
    property int queueIndex: -1
    property bool queueLoading: false
    property string queueStatus: "" // "", "ok", "notrack", "error"
    property string queueSourceKind: "" // "playlist" | "album" | ""
    property string queueSourceTitle: ""
    property string _queueAlbumId: ""
    property string _lastQueuePlaylistId: ""

    // playlists do usuário (baixadas uma vez, em background)
    property var userPlaylists: []
    property var playlistTracks: ({})
    property bool playlistsLoading: false
    property bool playlistsLoaded: false
    property int _playlistFetchIndex: -1

    function currentTrackUrl() {
        const md = root.player ? root.player.metadata : null;
        return md && md["xesam:url"] ? String(md["xesam:url"]) : "";
    }

    function trackIdFromUrl(url) {
        const m = url.match(/track\/(\d+)/);
        return m ? m[1] : "";
    }

    function loadUserPlaylists() {
        if (root.playlistsLoading || root.playlistsLoaded || Theme.deezerUserId === "")
            return;
        root.playlistsLoading = true;
        playlistsProc.command = ["curl", "-s", "--max-time", "10",
                                 "https://api.deezer.com/user/" + Theme.deezerUserId
                                 + "/playlists?limit=100"];
        playlistsProc.running = true;
    }

    function parseUserPlaylists(text) {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            data = null;
        }
        const list = data && data.data ? data.data : null;
        if (!list) {
            root.playlistsLoading = false;
            return;
        }
        const out = [];
        for (let i = 0; i < list.length; ++i)
            out.push({ id: String(list[i].id), title: list[i].title || "" });
        root.userPlaylists = out;
        root._playlistFetchIndex = 0;
        root.fetchNextPlaylistTracks();
    }

    function fetchNextPlaylistTracks() {
        const i = root._playlistFetchIndex;
        if (i < 0 || i >= root.userPlaylists.length) {
            root._playlistFetchIndex = -1;
            root.playlistsLoading = false;
            root.playlistsLoaded = true;
            root.refreshQueueSource();
            return;
        }
        playlistProc.command = ["curl", "-s", "--max-time", "15",
                                "https://api.deezer.com/playlist/"
                                + root.userPlaylists[i].id + "/tracks?limit=1000"];
        playlistProc.running = true;
    }

    function parsePlaylistTracks(text) {
        const i = root._playlistFetchIndex;
        if (i < 0 || i >= root.userPlaylists.length)
            return;
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (e) {
            data = null;
        }
        const list = data && data.data ? data.data : [];
        const out = [];
        for (let k = 0; k < list.length; ++k)
            out.push({
                id: String(list[k].id),
                title: list[k].title || "",
                duration: list[k].duration || 0,
                url: "https://deezer.com/track/" + list[k].id
            });
        root.playlistTracks[root.userPlaylists[i].id] = out;
        root._playlistFetchIndex = i + 1;
        playlistGap.restart();
    }

    function playlistTitle(pid) {
        for (let i = 0; i < root.userPlaylists.length; ++i)
            if (root.userPlaylists[i].id === pid)
                return root.userPlaylists[i].title;
        return "";
    }

    // escolhe a fonte da fila: playlist do usuário com a faixa, senão o álbum
    function refreshQueueSource() {
        const id = root.trackIdFromUrl(root.currentTrackUrl());
        if (id === "") {
            root.queueTracks = [];
            root.queueIndex = -1;
            root._queueAlbumId = "";
            root._lastQueuePlaylistId = "";
            root.queueSourceKind = "";
            root.queueSourceTitle = "";
            root.queueStatus = root.title === "" ? "" : "notrack";
            return;
        }
        if (root.playlistsLoaded) {
            // continuidade primeiro (faixas seguidas da mesma playlist)
            const candidates = [];
            if (root._lastQueuePlaylistId !== "")
                candidates.push(root._lastQueuePlaylistId);
            for (let i = 0; i < root.userPlaylists.length; ++i) {
                const pid = root.userPlaylists[i].id;
                if (pid !== root._lastQueuePlaylistId)
                    candidates.push(pid);
            }
            for (let c = 0; c < candidates.length; ++c) {
                const pid = candidates[c];
                const list = root.playlistTracks[pid];
                if (!list)
                    continue;
                for (let k = 0; k < list.length; ++k) {
                    if (list[k].id === id) {
                        root.queueTracks = list;
                        root.queueSourceKind = "playlist";
                        root.queueSourceTitle = root.playlistTitle(pid);
                        root.queueStatus = "ok";
                        root.queueLoading = false;
                        root._queueAlbumId = "";
                        root._lastQueuePlaylistId = pid;
                        root.rebuildQueueRows();
                        return;
                    }
                }
            }
        }
        // recomendação: não pertence a nenhuma playlist — mantém a última
        // detectada (o histórico continua exato)
        if (root._lastQueuePlaylistId !== "") {
            const list = root.playlistTracks[root._lastQueuePlaylistId];
            if (list) {
                root.queueTracks = list;
                root.queueSourceKind = "playlist";
                root.queueSourceTitle = root.playlistTitle(root._lastQueuePlaylistId);
                root.queueStatus = "ok";
                root.queueLoading = false;
                root._queueAlbumId = "";
                root.rebuildQueueRows();
                return;
            }
        }
        root.fetchAlbumQueue(id);
    }

    function fetchAlbumQueue(id) {
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
        const album = data && data.album ? data.album : null;
        const albumId = album && album.id ? String(album.id) : "";
        if (albumId === "") {
            root.queueLoading = false;
            root.queueTracks = [];
            root.queueIndex = -1;
            root.queueSourceKind = "";
            root.queueSourceTitle = "";
            root.queueStatus = "error";
            return;
        }
        if (albumId === root._queueAlbumId) {
            root.queueLoading = false;
            root.rebuildQueueRows();
            return;
        }
        root._queueAlbumId = albumId;
        root.queueSourceKind = "album";
        root.queueSourceTitle = album.title || "";
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
        root.queueSourceKind = "album";
        if (data.title)
            root.queueSourceTitle = data.title;
        root.rebuildQueueRows();
    }

    // registra a faixa atual no histórico (dedup por id; cap 60)
    function notePlayed() {
        const id = root.trackIdFromUrl(root.currentTrackUrl());
        if (id === "" || root.title === "")
            return;
        const h = root.playHistory;
        if (h.length > 0 && h[h.length - 1].id === id)
            return;
        const next = h.slice();
        next.push({
            id: id,
            title: root.title,
            duration: root.length,
            url: "https://deezer.com/track/" + id
        });
        while (next.length > 60)
            next.shift();
        root.playHistory = next;
    }

    // monta as linhas da seção: tocadas (histórico) + atual + próximas da playlist
    function rebuildQueueRows() {
        const rows = [];
        const hist = root.playHistory;
        const currentId = root.trackIdFromUrl(root.currentTrackUrl());

        // já tocadas = histórico sem a atual
        let played = hist;
        if (played.length > 0 && currentId !== "" && played[played.length - 1].id === currentId)
            played = played.slice(0, played.length - 1);
        for (let i = 0; i < played.length; ++i)
            rows.push({ kind: "played", id: played[i].id, title: played[i].title,
                        duration: played[i].duration, url: played[i].url });

        // atual
        if (currentId !== "" || root.title !== "") {
            const cur = hist.length > 0 && hist[hist.length - 1].id === currentId
                        ? hist[hist.length - 1] : null;
            rows.push({
                kind: "current",
                id: currentId,
                title: cur ? cur.title : root.title,
                duration: cur ? cur.duration : root.length,
                url: currentId !== "" ? "https://deezer.com/track/" + currentId : ""
            });
            root.queueIndex = rows.length - 1;
        } else {
            root.queueIndex = -1;
        }

        // próximas: da playlist, depois da atual (ou do último ponto conhecido),
        // sem repetir o que já tocou nem a atual
        const seen = {};
        for (let i = 0; i < hist.length; ++i)
            seen[hist[i].id] = true;
        if (currentId !== "")
            seen[currentId] = true;
        const list = root.queueTracks;
        let anchor = -1;
        for (let i = 0; i < list.length; ++i)
            if (list[i].id === currentId) {
                anchor = i;
                break;
            }
        if (anchor < 0) {
            for (let h = hist.length - 1; h >= 0 && anchor < 0; --h) {
                for (let i = 0; i < list.length; ++i)
                    if (list[i].id === hist[h].id) {
                        anchor = i;
                        break;
                    }
            }
        }
        for (let i = anchor + 1; i < list.length && rows.length < 200; ++i) {
            if (seen[list[i].id])
                continue;
            rows.push({ kind: "upcoming", id: list[i].id, title: list[i].title,
                        duration: list[i].duration, url: list[i].url });
        }

        root.queueRows = rows;
    }

    function playQueueTrack(url) {
        if (root.player && root.player.dbusName !== "")
            Quickshell.execDetached(["busctl", "--user", "call", root.player.dbusName,
                                     "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2",
                                     "OpenUri", "s", url]);
    }

    Process {
        id: playlistsProc
        stdout: StdioCollector { onStreamFinished: root.parseUserPlaylists(text) }
    }

    Process {
        id: playlistProc
        stdout: StdioCollector { onStreamFinished: root.parsePlaylistTracks(text) }
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
        onTriggered: root.refreshQueueSource()
    }

    Timer {
        id: playlistGap
        interval: 120
        onTriggered: root.fetchNextPlaylistTracks()
    }

    onSectionChanged: {
        if (section !== 3)
            return;
        loadUserPlaylists();
        if (queueTracks.length === 0 && title !== "")
            refreshQueueSource();
    }

    // ---------- troca de faixa ----------
    function refreshTrack() {
        root.livePosition = root.position;
        root.notePlayed();
        root.rebuildQueueRows();
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

    Component.onCompleted: {
        root.loadUserPlaylists();
        if (root.title !== "")
            root.refreshTrack();
    }

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
        function getQueue(): string { return root.queueSourceKind + " " + root.queueIndex + "/" + root.queueTracks.length; }
        function getPlaylists(): string { return (root.playlistsLoaded ? "ok" : (root.playlistsLoading ? "carregando" : "nao")) + " " + root.userPlaylists.length + "/" + Object.keys(root.playlistTracks).length; }
        function section(n: int): void { root.section = n; }
        function panel(open: bool): void { root.panelOpen = open; }
    }
}
