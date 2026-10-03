// Lumen — shell Quickshell para CachyOS (Umbriel opcional)
// Rode com: qs -c lumen
//
// Este arquivo é o ponto de entrada. Ele cria uma barra por monitor e
// força a inicialização dos singletons de serviço.

import Quickshell

ShellRoot {
    // Referenciar os singletons aqui força a criação deles na inicialização,
    // mesmo antes de algum widget precisar deles.
    readonly property var _notifications: Notifications.trackedNotifications
    readonly property var _workspaces: Workspaces.displayItems
    readonly property var _umbriel: Umbriel.workspaces

    // Uma barra por monitor conectado
    Variants {
        model: Quickshell.screens

        Bar {
            screen: modelData
        }
    }
}
