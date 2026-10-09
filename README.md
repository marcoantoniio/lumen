# Skye

**A desktop shell for Wayland, built with [Quickshell](https://quickshell.org/) (QML).**

Made to live well with the [Umbriel](https://github.com/noctalia-dev/umbriel) compositor,
but it works on any compositor with `wlr-layer-shell` — KWin, Hyprland, niri, Sway…

![Wayland](https://img.shields.io/badge/Wayland-000000?style=flat-square&logo=wayland&logoColor=white)
![Quickshell](https://img.shields.io/badge/Quickshell-0.3.1-f4be9e?style=flat-square)
![CachyOS](https://img.shields.io/badge/CachyOS-ready-00c1a2?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-efeceb?style=flat-square)

---

## ✨ Features

### Dynamic island

- **Floating pill-shaped bar**, one per monitor, with clicks passing through
  outside the pill (`mask`/`Region`).
- **Idle shows only the clock**; on hover, the pill **expands with an
  animation** (width + slide + fade) and reveals the side elements.
- **Recording**: the island becomes the **REC** indicator — pulsing red dot,
  recording time and pause/resume and stop buttons.
- **Volume**: when the volume/mute changes (media keys, apps), the island shows
  an **OSD** with a bar and percentage (it hides by itself).
- **Music**: while music is playing, the island shows the **album art** +
  animated equalizer bars + title.
- **The island adapts to the panels**: when a panel opens, it grows to the
  panel width and merges into it (no gap or divider line); when it closes, it
  goes back to normal — all animated.
- **Left (hover)**: desktop/workspace dots — **KWin via D-Bus** or
  Umbriel (automatic fallback). The current desktop gets bigger and lit; click
  switches desktop. Next to them, the bell with a dot when there are
  notifications.
- **Right (hover)**: three circular buttons **with colors only**; the selected
  one gets a soft radial-gradient glow:
  - **Orange** — notifications (opens/closes the panel)
  - **Magenta** — Control Center (opens/closes)
  - **Cyan** — Recent (opens/closes the recent files panel — hub)

### Control Center

- Tabs: **Control Center | Dashboard | Clipboard & Notes** (fixed height, no
  "jumping" when switching tabs).
- **Control Center**: Quick Settings (Network, Do Not Disturb, Night Light,
  Caffeine, Bluetooth, **Recorder** — records the screen and lights up while
  recording, **Camera** — webcam preview) + Session (Lock, Log out, Restart,
  Shut down); **Levels** with Output/Microphone/Brightness sliders, mute on the
  icon and an **audio device picker** on the arrow; **app mixer** (the button
  swaps the Levels for the list of apps playing sound, with per-app slider and
  mute); media line (MPRIS).
- **Music**: hovering the island (with music playing) opens a panel with
  album art and **album-color glow**, controls (previous/play/next), seek,
  **audio output**, **per-app mixer** and **lyrics** (lrclib, with sync and the
  current line highlighted).
- **Dashboard**: greeting ("Good morning/afternoon/evening, Name"), **calendar**
  with the current week + mini-month, **weather** with hourly forecast
  (humidity, wind, rain) and **System** with CPU, RAM, GPU, temperature, disk
  and uptime — all with little bars.
- **Clipboard & Notes**: clipboard history (left click copies back, right click
  removes) and notes (multiple, with title, saved to
  `~/.local/share/skye/notes.json`).
- **Footer** with shortcuts: Terminal, Files, Browser, Clipboard, Settings and
  the **language toggle (pt-BR/EN)**.

### Notifications and services

- **Notification panel** with color-coded category tabs (they filter the
  list), "clear all", action buttons and the **system tray** in the footer.
- **Toasts** stacked in the top-right corner (up to 4, they hide by
  themselves).
- **Central theme** in `Theme.qml`: black background, warm white text
  (`#efeceb`), peach accent (`#f4be9e`).
- **Custom IPC** to control everything from the command line.

---

## 📦 Requirements

**Required**

| Package | For what |
|---|---|
| `quickshell` (≥ 0.3.1) | the shell itself |
| Nerd Font (`ttf-jetbrains-mono-nerd` or similar) | UI icons |
| `curl` | weather (wttr.in) |

**Optional** (each one enables a feature; without it the UI degrades on its own)

| Package | For what |
|---|---|
| `umbriel` | workspaces via the compositor IPC (otherwise uses KWin) |
| `pipewire` / `wireplumber` | volume and microphone sliders |
| `ddcutil` | external monitor brightness (DDC/CI) |
| `nvidia-smi` / `lm_sensors` | GPU and temperature on the Dashboard |
| `kitty` | terminal button in the footer |
| `wl-clipboard` | clipboard history (wl-paste/wl-copy) |
| `gammastep` | Night Light button |
| `network-manager-applet` | network icon in the tray (`nm-applet --indicator`, start it with the session) |
| `qt6-multimedia` | camera preview (Camera button) |
| `curl` | lyrics (lrclib) and album art |
| `gpu-screen-recorder` | all-screens recording (Recorder button; uses NVENC/GPU and system audio + microphone) |

---

## 🚀 Installation

```bash
git clone https://github.com/marcoantoniio/skye ~/.config/quickshell/skye
qs -c skye -n -d        # starts in the background
```

Stop / inspect:

```bash
qs -c skye kill         # quits
qs -c skye list         # shows running instances
qs -c skye log          # prints the logs
```

### Start with the session (optional)

Via user systemd:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/skye.service <<'EOF'
[Unit]
Description=Skye (Quickshell shell)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
# NVIDIA + Wayland: Qt may fall back to the basic render loop (~60 fps);
# Vulkan uses the threaded render loop. Uncomment if animations feel capped.
# Environment=QSG_RHI_BACKEND=vulkan
# On setups with monitors of different refresh rates, the default animation
# driver steps at the primary screen's rate; this keeps animations in real
# time on the faster monitor. Uncomment if animations look ~60 fps.
# Environment=QSG_USE_SIMPLE_ANIMATION_DRIVER=1
ExecStart=/usr/bin/qs -c skye -n
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user enable --now skye.service
```

Or copy a `.desktop` file into `~/.config/autostart/` (and into
`~/.local/share/applications/` if you want to launch it from the menu):

```ini
[Desktop Entry]
Type=Application
Name=Skye Shell
Exec=qs -c skye -n -d
Icon=video-display
Terminal=false
Categories=Utility;
```

---

## 🎮 How to use

- **Idle**: only the clock. **Hover**: the island expands and reveals the
  controls.
- **Dots on the left**: click to switch desktop/workspace.
- **Buttons on the right**: notifications, Control Center and Recent.
- **In the panel**: use the tabs at the top; the footer has the app shortcuts.

---

## ⌨️ IPC

```bash
qs -c skye ipc show                          # lists everything available

qs -c skye ipc call notifications toggle     # notifications panel
qs -c skye ipc call notifications toggleDnd  # do not disturb
qs -c skye ipc call controlcenter toggle     # control center
qs -c skye ipc call controlcenter setTab 1   # 0=CC, 1=Dashboard, 2=Clipboard
qs -c skye ipc call controlcenter toggleMixer  # app mixer (instead of Levels)
qs -c skye ipc call workspaces switchToIndex 1
qs -c skye ipc call brightness set 40        # brightness (DDC/CI)
qs -c skye ipc call weather refresh
qs -c skye ipc call clipboard copy "text"
qs -c skye ipc call recorder start           # records all screens (~/Videos)
qs -c skye ipc call recorder pause           # pauses/resumes recording
qs -c skye ipc call recorder stop            # stops and saves the file
qs -c skye ipc call music status             # current music (MPRIS)
qs -c skye ipc call music toggle             # play/pause
qs -c skye ipc call audio setVolume 0.5      # output volume (shows the OSD)
qs -c skye ipc call timer pomodoro           # pomodoro/stopwatch (no UI yet)
qs -c skye ipc call timer status             # pomodoro/stopwatch state
qs -c skye ipc call camera toggle            # camera preview
qs -c skye ipc call recent toggle            # recent files panel (hub)
qs -c skye ipc call language toggle          # language: pt-BR/EN
```

---

## 🎨 Customization

> [!WARNING]
> The globe button in the Control Center footer opens **`https://localhost`** —
> the repository author's **local SearXNG** instance. If your machine doesn't
> run SearXNG there (or it runs on another host/port), change the URL in
> `ControlCenterPanel.qml` (footer, globe icon) or point it to the search
> engine of your choice.

| I want to change… | File |
|---|---|
| Colors, fonts and metrics | `Theme.qml` |
| Weather city (coordinates) | `Weather.qml` → `location` |
| Friendly disk names | `ControlCenterPanel.qml` → `diskName()` |
| Terminal button command | `ControlCenterPanel.qml` (footer) |
| Browser button URL (local SearXNG) | `ControlCenterPanel.qml` (footer) |
| Panel size | `Theme.qml` → `controlCenterPanelWidth` |
| Camera panel screen | `Theme.qml` → `cameraScreenName` |
| Dynamic island monitor | `Theme.qml` → `barScreenName` |

Colors use Qt's `#AARRGGBB` format (the `AA` is the transparency).

---

## 📁 Structure

| File | Role |
|---|---|
| `shell.qml` | entry point; creates one bar per monitor |
| `Theme.qml` | theme (colors, fonts, metrics) and panel widths |
| `I18n.qml` | translations (pt-BR/EN) and language IPC |
| `Bar.qml` | the dynamic island (collapses/expands on hover) |
| `Clock.qml`, `Bell.qml`, `WorkspacePills.qml`, `CategoryButtons.qml`, `CategoryCircle.qml` | island widgets |
| `ControlCenter.qml`, `ControlCenterPanel.qml`, `PanelTab.qml`, `QuickToggle.qml`, `LevelRow.qml`, `LevelSlider.qml`, `DeviceMenu.qml`, `FooterIcon.qml` | Control Center |
| `CalendarCard.qml`, `WeatherCard.qml`, `SystemCard.qml`, `Weather.qml`, `Greeting.qml` | Dashboard |
| `Clipboard.qml` | clipboard history |
| `Notes.qml` | notes (persisted in `~/.local/share/skye`) |
| `Brightness.qml` | DDC/CI brightness |
| `Workspaces.qml`, `Umbriel.qml` | desktops (KWin + Umbriel) |
| `Notifications.qml`, `NotificationCenter.qml`, `NotificationPopup.qml`, `NotificationPopups.qml`, `FilterTab.qml` | notifications |
| `Tray.qml` | system tray |
| `RecentFiles.qml`, `RecentFilesPanel.qml` | recent files panel (cyan button hub) |

---

## 📝 Notes and limitations

- The Control Center panel has a **fixed height** so it doesn't reposition when
  switching tabs.
- **Notifications**: the shell needs to own
  `org.freedesktop.Notifications`. Under KDE with plasmashell running, the
  native panel wins — under Umbriel (or without plasmashell) it works normally.
- **Workspaces**: uses KWin via D-Bus; under Umbriel it automatically falls back
  to the compositor IPC.
- **Clipboard**: the history uses `wl-clipboard` (`wl-paste --watch` +
  `wl-copy`); without it installed, the tab shows "unavailable".
- **Brightness**: depends on the monitor supporting DDC/CI.
- The audio device menu doesn't close when clicking outside (a limitation of
  nested popups on Wayland); close it by clicking the arrow or picking an item.

---

## 📚 Documentation

- Quickshell: <https://quickshell.org/docs/>
- Umbriel (compositor): <https://docs.noctalia.dev/umbriel/>

---

## 📄 License

MIT — see [`LICENSE`](LICENSE).
