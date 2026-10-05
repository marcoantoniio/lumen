pragma Singleton

// Estado global da ilha (pílula), compartilhado entre os monitores.
// O hover é escrito pela barra onde o mouse está (só em mudanças), e os
// painéis usam para fechar apenas quando o mouse sai de TUDO (ilha + painel),
// em qualquer tela.

import Quickshell
import QtQuick

Singleton {
    property bool hovered: false
}
