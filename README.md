# Lumen

**Um shell desktop para Wayland, feito com [Quickshell](https://quickshell.org/) (QML).**

Feito para viver bem com o compositor [Umbriel](https://github.com/noctalia-dev/umbriel),
mas funciona em qualquer compositor com `wlr-layer-shell` — KWin, Hyprland, niri, Sway…

![Wayland](https://img.shields.io/badge/Wayland-000000?style=flat-square&logo=wayland&logoColor=white)
![Quickshell](https://img.shields.io/badge/Quickshell-0.3.1-f4be9e?style=flat-square)
![CachyOS](https://img.shields.io/badge/CachyOS-ready-00c1a2?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-efeceb?style=flat-square)

---

## ✨ Features

### Ilha dinâmica

- **Barra flutuante em pílula**, uma por monitor, com clique atravessando fora
  da pílula (`mask`/`Region`).
- **Idle mostra só o relógio**; ao passar o mouse, a pílula **expande com
  animação** (largura + slide + fade) e revela os elementos laterais.
- **Gravando**: a ilha vira o indicador **REC** — bolinha vermelha pulsando,
  tempo de gravação e botões de pausar/continuar e parar.
- **A ilha se adapta aos painéis**: quando um painel abre, ela cresce até a
  largura dele e se funde ao painel (sem vão nem linha divisória); ao fechar,
  volta ao normal — tudo animado.
- **Esquerda (hover)**: dots dos desktops/workspaces — **KWin via D-Bus** ou
  Umbriel (fallback automático). O desktop atual fica maior e aceso; clique
  troca de desktop. Ao lado, o sino com dot quando há notificações.
- **Direita (hover)**: três botões circulares **só com cores**; o selecionado
  ganha um brilho suave em gradiente radial:
  - **Laranja** — notificações (abre/fecha o painel)
  - **Magenta** — Control Center (abre/fecha)
  - **Ciano** — Não Perturbe (silencia toasts, mantém tudo no histórico)

### Control Center

- Abas: **Control Center | Dashboard | Clipboard & Notes** (altura fixa, sem
  "pular" ao trocar de aba).
- **Control Center**: Quick Settings (Rede, Não Perturbe, Night Light,
  Caffeine, Bluetooth, **Gravador** — grava a tela e acende durante a gravação)
  + Sessão (Bloquear, Sair, Reiniciar,
  Desligar); **Levels** com sliders de Saída/Microfone/Brilho, mute no ícone e
  **seletor de dispositivos de áudio** na setinha; linha de mídia (MPRIS).
- **Dashboard**: saudação ("Bom dia/Boa tarde/Boa noite, Nome"), **calendário**
  com semana atual + mini-mês, **clima** com previsão horária (umidade, vento,
  chuva) e **Sistema** com CPU, RAM, GPU, temperatura, disco e uptime — tudo
  com barrinhas.
- **Clipboard & Notes**: histórico do clipboard (clique copia de volta) e
  notas persistentes.
- **Rodapé** com atalhos: Terminal, Arquivos, Navegador, Clipboard e
  Configurações.

### Notificações e serviços

- **Painel de notificações** com abas coloridas por categoria (filtram a
  lista), "limpar tudo", botões de ação e **bandeja do sistema** no rodapé.
- **Toasts** empilhados no canto superior direito (até 4, somem sozinhos).
- **Tema central** em `Theme.qml`: fundo preto, texto branco quente
  (`#efeceb`), destaque pêssego (`#f4be9e`).
- **IPC próprio** para controlar tudo por linha de comando.

---

## 📦 Requisitos

**Obrigatórios**

| Pacote | Para quê |
|---|---|
| `quickshell` (≥ 0.3.1) | o shell em si |
| Fonte Nerd Font (`ttf-jetbrains-mono-nerd` ou similar) | ícones da UI |
| `curl` | clima (wttr.in) |

**Opcionais** (cada um habilita uma feature; sem ele, a UI degrada sozinha)

| Pacote | Para quê |
|---|---|
| `umbriel` | workspaces via IPC do compositor (senão usa KWin) |
| `pipewire` / `wireplumber` | sliders de volume e microfone |
| `ddcutil` | brilho de monitor externo (DDC/CI) |
| `nvidia-smi` / `lm_sensors` | GPU e temperatura no Dashboard |
| `kitty` | botão do terminal no rodapé |
| Klipper (KDE) | histórico do clipboard |
| `gammastep` | botão Night Light |
| `gpu-screen-recorder` | gravação de tela (botão Gravador; usa NVENC/GPU e áudio do sistema + microfone) |

---

## 🚀 Instalação

```bash
git clone https://github.com/marcoantoniio/lumen ~/.config/quickshell/lumen
qs -c lumen -n -d        # inicia em segundo plano
```

Parar / inspecionar:

```bash
qs -c lumen kill         # encerra
qs -c lumen list         # mostra instâncias rodando
qs -c lumen log          # imprime os logs
```

### Iniciar junto com a sessão (opcional)

Via systemd de usuário:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/lumen.service <<'EOF'
[Unit]
Description=Lumen (Quickshell shell)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/qs -c lumen -n
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user enable --now lumen.service
```

Ou copie um `.desktop` para `~/.config/autostart/` (e para
`~/.local/share/applications/` se quiser abrir pelo menu):

```ini
[Desktop Entry]
Type=Application
Name=Lumen Shell
Exec=qs -c lumen -n -d
Icon=video-display
Terminal=false
Categories=Utility;
```

---

## 🎮 Como usar

- **Repouso**: só o relógio. **Hover**: a ilha expande e revela os controles.
- **Dots à esquerda**: clique para trocar de desktop/workspace.
- **Botões à direita**: notificações, Control Center e Não Perturbe.
- **No painel**: use as abas no topo; o rodapé tem os atalhos de apps.

---

## ⌨️ IPC

```bash
qs -c lumen ipc show                          # lista tudo que existe

qs -c lumen ipc call notifications toggle     # painel de notificações
qs -c lumen ipc call notifications toggleDnd  # não perturbe
qs -c lumen ipc call controlcenter toggle     # control center
qs -c lumen ipc call controlcenter setTab 1   # 0=CC, 1=Dashboard, 2=Clipboard
qs -c lumen ipc call workspaces switchToIndex 1
qs -c lumen ipc call brightness set 40        # brilho (DDC/CI)
qs -c lumen ipc call weather refresh
qs -c lumen ipc call clipboard copy "texto"
qs -c lumen ipc call recorder start           # grava a tela inteira (~/Videos)
qs -c lumen ipc call recorder pause           # pausa/retoma a gravação
qs -c lumen ipc call recorder stop            # para e salva o arquivo
```

---

## 🎨 Personalização

| Quero mudar… | Arquivo |
|---|---|
| Cores, fontes e métricas | `Theme.qml` |
| Cidade do clima (coordenadas) | `Weather.qml` → `location` |
| Nomes amigáveis dos discos | `ControlCenterPanel.qml` → `diskName()` |
| Comando do botão terminal | `ControlCenterPanel.qml` (rodapé) |
| Tamanho do painel | `Theme.qml` → `controlCenterPanelWidth` |

As cores seguem o formato `#AARRGGBB` do Qt (o `AA` é a transparência).

---

## 📁 Estrutura

| Arquivo | Papel |
|---|---|
| `shell.qml` | entrada; cria uma barra por monitor |
| `Theme.qml` | tema (cores, fontes, métricas) e larguras dos painéis |
| `Bar.qml` | a ilha dinâmica (colapsa/expande no hover) |
| `Clock.qml`, `Bell.qml`, `WorkspacePills.qml`, `CategoryButtons.qml`, `CategoryCircle.qml` | widgets da ilha |
| `ControlCenter.qml`, `ControlCenterPanel.qml`, `PanelTab.qml`, `QuickToggle.qml`, `LevelRow.qml`, `LevelSlider.qml`, `DeviceMenu.qml`, `FooterIcon.qml` | Control Center |
| `CalendarCard.qml`, `WeatherCard.qml`, `SystemCard.qml`, `Weather.qml`, `Greeting.qml` | Dashboard |
| `Clipboard.qml` | histórico do clipboard |
| `Brightness.qml` | brilho DDC/CI |
| `Workspaces.qml`, `Umbriel.qml` | desktops (KWin + Umbriel) |
| `Notifications.qml`, `NotificationCenter.qml`, `NotificationPopup.qml`, `NotificationPopups.qml`, `FilterTab.qml` | notificações |
| `Tray.qml` | bandeja do sistema |

---

## 📝 Notas e limitações

- O painel do Control Center tem **altura fixa** para não reposicionar ao trocar
  de aba.
- **Notificações**: o shell precisa ser o dono de
  `org.freedesktop.Notifications`. Sob KDE com plasmashell rodando, o painel
  nativo ganha — sob Umbriel (ou sem plasmashell) funciona normalmente.
- **Workspaces**: usa KWin via D-Bus; sob Umbriel cai automaticamente para o
  IPC do compositor.
- **Clipboard**: o histórico vem do Klipper (KDE); em outros compositores a aba
  mostra "indisponível".
- **Brilho**: depende do monitor suportar DDC/CI.
- O menu de dispositivos de áudio não fecha ao clicar fora (limitação de popups
  aninhados no Wayland); feche clicando na setinha ou escolhendo um item.

---

## 📚 Documentação

- Quickshell: <https://quickshell.org/docs/>
- Umbriel (compositor): <https://docs.noctalia.dev/umbriel/>

---

## 📄 Licença

MIT — veja [`LICENSE`](LICENSE).
