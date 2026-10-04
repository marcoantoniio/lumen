pragma Singleton

// Estado do painel de teste da câmera (Webcam).
//
// IPC:
//   qs -c lumen ipc call camera toggle|open|close

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false

    function toggle(): void {
        root.open = !root.open;
        if (root.open) {
            ControlCenter.open = false;
            RecentFiles.open = false;
        }
    }

    function open(): void {
        root.open = true;
        ControlCenter.open = false;
        RecentFiles.open = false;
    }

    IpcHandler {
        target: "camera"

        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.open = false; }
    }
}
