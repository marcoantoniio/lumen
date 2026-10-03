pragma Singleton

// Histórico do clipboard via Klipper (KDE).
// - getClipboardHistoryMenu retorna a lista (o primeiro item é o atual).
// - copyItem() devolve um item para o clipboard.
// - Em compositores sem Klipper, `available` fica false e a UI avisa.
//
// IPC: qs -c ariel ipc call clipboard refresh|clear|copy <texto>

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var items: []
    property bool available: false

    function refresh() {
        if (!query.running)
            query.running = true;
    }

    function copyItem(text) {
        setProc.command = ["qdbus6", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper.setClipboardContents", text];
        setProc.running = true;
    }

    function clearHistory() {
        items = [];
        if (!clearProc.running)
            clearProc.running = true;
    }

    Process {
        id: query

        command: ["qdbus6", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper.getClipboardHistoryMenu"]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").map(l => l.replace(/\r$/, "")).filter(l => l.length > 0);
                // Só atualiza se mudou (evita rebuild da lista a cada refresh)
                if (JSON.stringify(list) !== JSON.stringify(root.items))
                    root.items = list;
                root.available = true;
            }
        }

        onExited: (code) => {
            if (code !== 0)
                root.available = false;
        }
    }

    Process {
        id: setProc
    }

    Process {
        id: clearProc

        command: ["qdbus6", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper.clearClipboardHistory"]

        onExited: root.refresh()
    }

    IpcHandler {
        target: "clipboard"

        function refresh(): void { root.refresh(); }
        function clear(): void { root.clearHistory(); }
        function copy(text: string): void { root.copyItem(text); }
    }
}
