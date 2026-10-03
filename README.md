# Umbra

Shell Quickshell para CachyOS, feita para viver bem com o compositor **Umbriel**
(mas funciona em qualquer compositor com wlr-layer-shell, como KWin/Hyprland/niri).
O painel do Control Center tem altura fixa (410px) para não "pular" ao trocar de aba.

## O que já tem

- **Barra flutuante em pílula**, uma por monitor, com clique passando direto
  fora da pílula (`mask`/`Region`).
- **A ilha se adapta aos painéis**: quando um painel abre, ela cresce até a
  largura dele e se funde ao painel (sem vão nem linha divisória, cantos retos
  na junção); ao fechar, volta ao normal — tudo animado.
- **Idle mostra só o relógio**; ao passar o mouse, a pílula **expande com
  animação** (largura + slide + fade) e revela os elementos laterais.
- **Esquerda (no hover)**: dots de desktop/workspace — **KWin via D-Bus** ou
  Umbriel (fallback automático). Tudo em tons de cinza; o desktop atual fica
  maior e aceso. Clique troca de desktop. Ao lado, o sino com dot quando há
  notificações.
- **Direita (no hover)**: três botões circulares **só com cores** (sem ícones);
  o selecionado ganha um brilho suave em gradiente radial:
  - **Laranja** = notificações (abre/fecha o painel)
  - **Magenta** = Control Center (abre/fecha)
  - **Ciano** = Não Perturbe (DND): silencia os toasts, mantém tudo no histórico
- **Control Center** (inspirado na referência), aberto pela bolinha do meio:
  - Abas: **Control Center | Dashboard | Clipboard & Notes**
  - Control Center em **duas colunas**: "Quick Settings" (Rede, Não Perturbe,
    Night Light*, Caffeine, Bluetooth*, Gravador) + "Sessão" (Bloquear, Sair,
    Reiniciar, Desligar) à esquerda; "Levels" (Saída, Microfone e **Brilho**
    via DDC/CI com sliders + mute) e mídia à direita. A **setinha** ao lado de
    Saída/Microfone abre o **seletor de dispositivos** de áudio. (* Night Light
    funciona se instalar `gammastep`; Bluetooth se houver adaptador)
  - **Dashboard**: **saudação** no topo ("Bom dia/Boa tarde/Boa noite, Nome")
    e 3 colunas, como na referência:
    - **Calendário**: semana atual, iniciais dos dias, hoje em pílula clara,
      **mini-mês** completo (com hoje destacado), intervalo e nº da semana
    - **Clima** (Brasília, via wttr.in): temperatura, condição, máx/mín, chuva
      e **2 faixas horizontais** de previsão (hora, temp, sensação, umidade,
      vento e chuva)
    - **Sistema**: CPU, RAM, **GPU (nvidia-smi)**, Temp (sensors), **root** e
      Uptime, cada um com barrinha
  - **Rodapé** (em todas as abas): 5 ícones funcionais — **Terminal**
    (abre o kitty), **Arquivos** (abre a home), **Navegador** (abre o
    navegador padrão), **Clipboard** (vai para a aba Clipboard & Notes) e
    **Configurações** (abre o systemsettings)
  - **Clipboard & Notes**: **histórico do clipboard via Klipper** (clique copia
    de volta, botão "limpar") + notas persistidas. O painel tem altura fixa
    para não "pular" ao trocar de aba.
- **Painel de notificações** com abas coloridas por categoria (filtram a lista),
  "limpar tudo", botões de ação e **bandeja do sistema no rodapé** (System Tray).
- **Toasts** empilhados no canto superior direito (até 4, somem sozinhos).
- **Tema central** em `Theme.qml` (cores, fontes, métricas) — paleta quente
  inspirada na referência: fundo preto, texto branco quente (`#efeceb`),
  destaque pêssego (`#f4be9e`) com conteúdo escuro por cima (`accentInk`) e
  botões da ilha em pêssego/magenta/ciano.
- **IPC** próprio: `qs -c umbra ipc call notifications|controlcenter ...`.

## Requisitos

```bash
sudo pacman -S quickshell        # 0.3.1 nos repos do CachyOS
# opcional, para workspaces:
sudo pacman -S umbriel xdg-desktop-portal-umbriel
```

## Rodar

```bash
qs -c umbra          # inicia em primeiro plano (logs no terminal; Ctrl+C encerra)
qs -c umbra -d       # daemonizado (segundo plano)
qs -c umbra -n -d    # idem, mas não inicia duplicado
```

Parar / inspecionar:

```bash
qs -c umbra kill     # encerra a instância
qs -c umbra list     # mostra instâncias rodando
qs -c umbra log      # imprime os logs
```

Ou pelo menu de aplicativos: **Umbra Shell** (atalho em
`~/.local/share/applications/umbra.desktop`).

### Iniciar junto com a sessão (opcional)

Via systemd (recomendado):

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/umbra.service <<'EOF'
[Unit]
Description=Umbra (Quickshell shell)
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/qs -c umbra -n
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user enable --now umbra.service
```

Ou via autostart do desktop (KDE/GNOME): copie `umbra.desktop` para
`~/.config/autostart/`.

Testar sem sair da sessão atual (KDE etc.): a barra, relógio e tray aparecem;
notificações só funcionam se outro daemon (plasmashell) não estiver segurando
`org.freedesktop.Notifications`; workspaces só sob Umbriel.

> Status: testado em CachyOS/KDE Wayland com 2 monitores — barra, tray, relógio
> e painel de notificações (via IPC) renderizam corretamente. Sob Umbriel,
> workspaces e notificações passam a funcionar de verdade.

## IPC

```bash
qs -c umbra ipc show                         # lista targets/funções
qs -c umbra ipc call notifications toggle    # abre/fecha painel central
qs -c umbra ipc call notifications clearAll
qs -c umbra ipc call notifications getCount
qs -c umbra ipc call notifications toggleDnd # liga/desliga o Não Perturbe
qs -c umbra ipc call notifications getDnd
qs -c umbra ipc call controlcenter toggle    # abre/fecha o Control Center
qs -c umbra ipc call controlcenter setTab 0  # 0=Control Center, 1=Dashboard, 2=Clipboard
qs -c umbra ipc call controlcenter getTab
qs -c umbra ipc call controlcenter toggleCaffeine
qs -c umbra ipc call controlcenter getCaffeine
qs -c umbra ipc call controlcenter toggleNightLight
qs -c umbra ipc call clipboard refresh        # recarrega o histórico
qs -c umbra ipc call clipboard clear          # limpa o histórico
qs -c umbra ipc call clipboard copy "texto"   # joga um texto no clipboard
qs -c umbra ipc call brightness get           # brilho atual (DDC/CI)
qs -c umbra ipc call brightness set 40        # define o brilho (0-100)
qs -c umbra ipc call workspaces getCurrent    # índice do desktop atual
qs -c umbra ipc call workspaces switchToIndex 1
qs -c umbra ipc call weather refresh          # atualiza o clima na hora
```

## Estrutura

| Arquivo | Papel |
|---|---|
| `shell.qml` | entrada; cria uma `Bar` por monitor |
| `Theme.qml` | singleton de tema (cores/métricas/fontes) |
| `Umbriel.qml` | singleton do IPC do Umbriel (workspaces) |
| `Workspaces.qml` | desktops unificados (KWin D-Bus + fallback Umbriel) |
| `Notifications.qml` | singleton do NotificationServer + categorias/cores + IPC |
| `ControlCenter.qml` | singleton do Control Center (estado + IPC) |
| `Clipboard.qml` | singleton do histórico do clipboard (Klipper) |
| `Brightness.qml` | singleton do brilho via DDC/CI (ddcutil) |
| `Weather.qml` | singleton do clima (wttr.in) |
| `Greeting.qml` | singleton da saudação (nome do usuário + hora) |
| `CalendarCard.qml` | card de calendário do Dashboard |
| `WeatherCard.qml` | card de clima do Dashboard |
| `SystemCard.qml` | card de sistema do Dashboard (linhas + barras) |
| `Bar.qml` | a barra flutuante (colapsa/expande no hover) |
| `Clock.qml` | relógio |
| `WorkspacePills.qml` | dots de workspace |
| `Bell.qml` | sino + dot de notificação |
| `CategoryCircle.qml` | círculo colorido de ação (botão) |
| `CategoryButtons.qml` | os 3 botões de ação da barra |
| `ControlCenterPanel.qml` | o painel do Control Center (abas + páginas) |
| `PanelTab.qml` | aba do topo do Control Center |
| `QuickToggle.qml` | botão de quick setting / sessão |
| `LevelRow.qml` | linha de nível (ícone + slider + seta) |
| `DeviceMenu.qml` | seletor de dispositivos de áudio (dropdown) |
| `LevelSlider.qml` | slider de volume/mic |
| `FooterIcon.qml` | ícone do rodapé do painel |
| `FilterTab.qml` | aba/pílula colorida do painel |
| `Tray.qml` | bandeja do sistema (usada no rodapé do painel) |
| `NotificationPopups.qml` | pilha de toasts |
| `NotificationPopup.qml` | um toast |
| `NotificationCenter.qml` | painel de histórico com abas + tray |

## Próximos passos sugeridos

1. **Launcher** de aplicativos (`DesktopEntries` + `PopupWindow` + busca fuzzy).
2. **OSD** de volume/brilho (`Pipewire`, `UPower`, `PanelWindow` ignore).
3. **Night Light real**: `sudo pacman -S gammastep` (o botão já está pronto).
4. **Click-outside** nos painéis (overlay ou `grabFocus`).
5. Workspaces genéricos (`ext-workspace-v1`) quando o Quickshell suportar,
   para funcionar em qualquer compositor.

## Referências

- Quickshell: https://quickshell.org/docs/v0.3.1/
- Umbriel IPC: https://docs.noctalia.dev/umbriel/ipc/
- Exemplos oficiais: https://github.com/quickshell-mirror/quickshell-examples
- caelestia (referência avançada): https://github.com/caelestia-dots/shell
- Tide Island (dynamic island): https://github.com/enhaoswen/Tide-island
