// Botões circulares coloridos do lado direito da barra (só cores, sem ícones).
// Cada cor tem uma função:
// - Laranja: abre/fecha o painel de notificações.
// - Magenta: abre/fecha o Control Center.
// - Ciano: Não Perturbe (silencia toasts, mantém no histórico).
// O selecionado ganha brilho.

import QtQuick

Row {
    id: root

    spacing: 10

    // ---- notificações ----
    CategoryCircle {
        dotColor: Theme.accent
        selected: Notifications.centerOpen && Notifications.activeCategory === ""
        onActivated: Notifications.toggleAll()
    }

    // ---- control center ----
    CategoryCircle {
        dotColor: Theme.accentAlt
        selected: ControlCenter.open
        onActivated: ControlCenter.toggle()
    }

    // ---- não perturbe (DND) ----
    CategoryCircle {
        dotColor: Theme.accentCool
        selected: Notifications.dnd
        onActivated: Notifications.dnd = !Notifications.dnd
    }
}
