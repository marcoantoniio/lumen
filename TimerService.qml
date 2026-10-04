pragma Singleton

// Pomodoro + cronômetro. O estado vive aqui (fora do painel), então continua
// contando com o painel fechado. Ao concluir uma fase, toca um som e mostra um
// aviso na ilha.
//
// IPC:
//   qs -c lumen ipc call timer pomodoro|stopwatch|reset|status

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---------- pomodoro ----------
    readonly property int focusMinutes: 25
    readonly property int shortBreakMinutes: 5
    readonly property int longBreakMinutes: 15

    property int pomoPhase: 0 // 0 = ocioso, 1 = foco, 2 = pausa, 3 = pausa longa
    property int pomoRemaining: focusMinutes * 60
    property bool pomoRunning: false
    property int pomoCompleted: 0

    readonly property int pomoTotal: pomoPhase === 2 ? shortBreakMinutes * 60
        : pomoPhase === 3 ? longBreakMinutes * 60
        : focusMinutes * 60

    readonly property real pomoProgress: pomoTotal > 0 ? 1 - pomoRemaining / pomoTotal : 0

    readonly property string pomoLabel: pomoPhase === 1 ? "Foco"
        : pomoPhase === 2 ? "Pausa"
        : pomoPhase === 3 ? "Pausa longa"
        : "Pronto"

    function pomoToggle(): void {
        if (root.pomoPhase === 0) {
            root.pomoPhase = 1;
            root.pomoRemaining = root.focusMinutes * 60;
            root.pomoRunning = true;
            return;
        }
        root.pomoRunning = !root.pomoRunning;
    }

    function pomoReset(): void {
        root.pomoRunning = false;
        root.pomoPhase = 0;
        root.pomoRemaining = root.focusMinutes * 60;
    }

    function pomoSkip(): void {
        root.advancePhase(false);
    }

    function advancePhase(playSound) {
        if (playSound)
            Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/complete.oga"]);

        let message = "";
        if (root.pomoPhase === 1) {
            root.pomoCompleted += 1;
            root.pomoPhase = root.pomoCompleted % 4 === 0 ? 3 : 2;
            message = root.pomoPhase === 3 ? "Pausa longa!" : "Pausa!";
        } else {
            root.pomoPhase = 1;
            message = "Foco!";
        }

        root.pomoRemaining = root.pomoTotal;
        root.pomoRunning = true;
        root.showMessage(message);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pomoRunning
        onTriggered: {
            if (root.pomoRemaining > 0)
                root.pomoRemaining -= 1;
            if (root.pomoRemaining <= 0)
                root.advancePhase(true);
        }
    }

    // ---------- cronômetro ----------
    property bool swRunning: false
    property int swElapsed: 0
    property var laps: []

    function swToggle(): void {
        root.swRunning = !root.swRunning;
    }

    function swReset(): void {
        root.swRunning = false;
        root.swElapsed = 0;
        root.laps = [];
    }

    function swLap(): void {
        if (root.swElapsed <= 0)
            return;
        root.laps = [root.swElapsed, ...root.laps].slice(0, 20);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.swRunning
        onTriggered: root.swElapsed += 1
    }

    // ---------- aviso na ilha ----------
    property string message: ""
    property bool messageVisible: false

    function showMessage(text) {
        root.message = text;
        root.messageVisible = true;
        messageTimer.restart();
    }

    Timer {
        id: messageTimer
        interval: 4000
        onTriggered: root.messageVisible = false
    }

    function format(seconds) {
        const t = Math.max(0, Math.floor(seconds));
        const p = (n) => String(n).padStart(2, "0");
        const h = Math.floor(t / 3600);
        const m = Math.floor((t % 3600) / 60);
        const s = t % 60;
        return h > 0 ? h + ":" + p(m) + ":" + p(s) : p(m) + ":" + p(s);
    }

    IpcHandler {
        target: "timer"

        function pomodoro(): void { root.pomoToggle(); }
        function stopwatch(): void { root.swToggle(); }
        function reset(): void { root.pomoReset(); root.swReset(); }
        function status(): string {
            return "pomodoro: " + root.pomoLabel + " " + root.format(root.pomoRemaining)
                 + (root.pomoRunning ? " (rodando)" : " (parado)")
                 + " | cronômetro: " + root.format(root.swElapsed);
        }
    }
}
