pragma Singleton

// Estado global da ilha (pílula), compartilhado entre os monitores.
// O hover é escrito pela barra onde o mouse está (só em mudanças), e os
// painéis usam para fechar apenas quando o mouse sai de TUDO (ilha + painel),
// em qualquer tela.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool hovered: false

    // Formato da ilha: false = pílula arredondada flutuando; true = quadrada,
    // colada no topo da tela. Persiste entre reinícios do shell.
    property bool square: false

    onSquareChanged: Quickshell.execDetached(["sh", "-c",
        "printf '%s' '" + (square ? "1" : "0") + "' > '" + Quickshell.stateDir + "/island_square.txt'"])

    Process {
        id: loadProc

        command: ["cat", Quickshell.stateDir + "/island_square.txt"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.square = text.trim() === "1"
        }
    }
}
