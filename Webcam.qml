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
        if (!root.open) {
            ControlCenter.open = false;
            Notifications.centerOpen = false;
            RecentFiles.open = false;
            Music.panelOpen = false;
        }
        root.open = !root.open;
    }

    function show(): void {
        ControlCenter.open = false;
        Notifications.centerOpen = false;
        RecentFiles.open = false;
        Music.panelOpen = false;
        root.open = true;
    }

    function close(): void {
        root.open = false;
    }

    IpcHandler {
        target: "camera"

        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.close(); }
    }
}
