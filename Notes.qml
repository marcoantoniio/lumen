pragma Singleton

// Notas do Control Center: várias notas com título e corpo, persistidas em
// ~/.local/share/skye/notes.json (fica salvo no computador entre reinícios).

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var notes: [{ title: "", body: "" }]
    property int current: 0
    // incrementa quando as notas terminam de carregar do disco
    property int loadSeq: 0

    readonly property string notesDir: Quickshell.env("HOME") + "/.local/share/skye"
    readonly property string notesFile: notesDir + "/notes.json"

    function addNote() {
        const list = root.notes.slice();
        list.push({ title: "", body: "" });
        root.notes = list;
        root.current = list.length - 1;
        root.save();
    }

    function removeNote(i) {
        const list = root.notes.slice();
        list.splice(i, 1);
        if (list.length === 0)
            list.push({ title: "", body: "" });
        root.notes = list;
        let cur = root.current;
        if (i < cur)
            cur = cur - 1;
        root.current = Math.max(0, Math.min(cur, list.length - 1));
        root.loadSeq = root.loadSeq + 1;   // recarrega os campos (nota pode ter mudado)
        root.save();
    }

    function update(title, body) {
        if (root.current < 0 || root.current >= root.notes.length)
            return;
        const list = root.notes.slice();
        list[root.current] = { title: title, body: body };
        root.notes = list;
        saveTimer.restart();
    }

    function save() {
        const json = JSON.stringify(root.notes);
        writeProc.command = ["sh", "-c",
            "mkdir -p '" + notesDir + "' && printf '%s' \"$1\" > '" + notesFile + "'",
            "sh", json];
        writeProc.running = true;
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: root.save()
    }

    Process {
        id: writeProc
    }

    Process {
        id: readProc

        command: ["sh", "-c", "cat '" + notesFile + "' 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                let list = null;
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    list = null;
                }
                if (Array.isArray(list) && list.length > 0)
                    root.notes = list;
                root.current = 0;
                root.loadSeq = root.loadSeq + 1;
            }
        }
    }

    Component.onCompleted: readProc.running = true
}
