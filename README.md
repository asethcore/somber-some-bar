# Quickshell Bar

**A floating, Dynamic-Island-style status bar for Hyprland, built with Quickshell.**

A centre notch that rests quietly at the top of your screen, expands on hover to
reveal workspaces, media, a timer and a wallpaper picker, and hosts notifications,
a control center, an app drawer, Wi-Fi/Bluetooth menus, and live volume/brightness
OSDs — all controllable with your keyboard or the scroll wheel.

---

## About

This bar is heavily inspired by — and borrows from — the excellent work of others:

- [**Tide Island**](https://github.com/enhaoswen/Tide-island) (GPL-3.0) — the control
  center layout (Wi-Fi/Bluetooth cards, toggle switches, `ControlSliderCard`-style
  display/sound sliders), the minimal icon + text custom-info styling, and the general
  Dynamic Island ergonomics.
- The workspace-overview concept draws inspiration from **@end-4's** work (as Tide
  Island itself does).

Borrowed UI ideas were re-implemented in this codebase; where applicable this
project is distributed under the same spirit of open, hackable desktop software.

---

## Preview

| Workspaces | Media | Timer |
|---|---|---|
| ![Workspaces](screenshots/view0.png) | ![Media](screenshots/view1.png) | ![Timer](screenshots/view2.png) |

| Wallpapers | Notifications | Control Center |
|---|---|---|
| ![Wallpapers](screenshots/view3.png) | ![Notifications](screenshots/view4.png) | ![Control Center](screenshots/view5.png) |

| Volume OSD | Brightness OSD | Notification Popup |
|---|---|---|
| ![Volume](screenshots/popup-volume.png) | ![Brightness](screenshots/popup-brightness.png) | ![Notification](screenshots/popup-notification.png) |

> Screenshots are regenerable via the IPC commands (see *Common Commands*).

---

## Features

### Centre Notch (hover to expand, scroll to cycle)

- **Workspace overview** — live minimap of each occupied workspace with per-window
  app icons (`WsPreview`).
- **Media player** — now-playing card with cover art, progress bar, and prev/play/next
  controls (`MediaPlayer`, `CoverArt`).
- **Timer** — ring-progress countdown timer with hours/minutes inputs (`TimerPage`).
- **Wallpaper picker** — scrollable gallery of your wallpapers with one-click apply
  (`WallpaperPicker`).

### Right Pill

- **Battery** — circular charge ring + bolt icon.
- **Bell** — opens the **Notification Centre** (history list, clear-all).
- **Gear** — opens the **Control Center**.

### Control Center

- **Wi-Fi** and **Bluetooth** cards with iOS-style toggles and status/chevron.
- **Display** and **Sound** slider cards (Tide-style track + knob).

### Dropdowns

- **App Drawer** — search apps, files, or math; launch on Enter (`AppDrawer`).
- **Wi-Fi menu** — scan for networks, shows signal strength + security, connects to
  open/known networks, prompts for a password on secure ones.
- **Bluetooth menu** — groups devices into Connected / Paired / Available, pairs and
  connects via `bluetoothctl`.

### OSDs (shown in the notch)

- **Volume** OSD when using the volume keys.
- **Brightness** OSD when using the brightness keys.
- **Notification** popup for incoming desktop notifications.

### Input / Interactivity

- Scroll the wheel on the notch to cycle views.
- `Escape` closes whatever popup is open.
- The notch auto-collapses when you move the cursor away (except pinned
  control-center / notification views).

---

## Requirements

Runtime tools (all used by the bar):

| Tool | Purpose |
|---|---|
| `quickshell` (≥ 0.3) | the shell runtime |
| Hyprland | the compositor (workspace/clients IPC, `hyprctl`) |
| JetBrainsMono Nerd Font | icons and UI text |
| `wpctl` (WirePlumber) | volume read/control |
| `brightnessctl` + udev rule | brightness read/control |
| `bluetoothctl` (bluez) | bluetooth pairing/connection |
| NetworkManager | Wi-Fi backend (via `Quickshell.Networking`) |
| `bash`, `nc` (netcat) | socket IPC from keybindings |
| `grim`, `slurp`, `wl-copy`, `wl-paste`, `jq` | screenshots (optional, for the Print binds) |
| `hyprlock` | lock action |

Quickshell services used: `Quickshell.Hyprland`, `.Networking`, `.Bluetooth`,
`.Services.Mpris`, `.Services.Notifications`, `.Services.UPower`, `.Io`,
`.Widgets`, `.Wayland`.

---

## Installation

### 1. Clone the bar

```sh
git clone https://github.com/asethcore/some-bar.git ~/quickshell-bar
```

### 2. Install dependencies

**Arch / AUR:**

```sh
sudo pacman -S quickshell hyprland wireplumber bluez networkmanager \
  brightnessctl ttf-jetbrains-mono-nerd grim slurp wl-clipboard jq \
  hyprlock inetutils
# or via an AUR helper:
yay -S quickshell
```

**NixOS** (flake or configuration.nix):

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    quickshell
    hyprland
    wireplumber          # wpctl
    bluez                # bluetoothctl
    networkmanager
    brightnessctl
    nerd-fonts.jetbrains-mono
    grim slurp wl-clipboard jq
    hyprlock
    netcat
  ];

  hardware.bluetooth.enable = true;
  networking.networkmanager.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="backlight", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';
  users.users.<you>.extraGroups = [ "video" ];
}
```

**Debian/Ubuntu/Fedora/openSUSE** — install the same tools via your package manager
(`quickshell` is available on most rolling distros; otherwise build it from
[github.com/quickshell/quickshell](https://github.com/quickshell/quickshell)).

### 3. Start the bar

Add to your `hyprland.lua` (or `hyprland.conf`):

```lua
hl.exec_cmd("quickshell -p /home/seth/quickshell-bar")
```

or

```conf
exec-once = quickshell -p /home/seth/quickshell-bar
```

### 4. Wire the IPC + keybindings

The bar exposes a Unix socket at `/tmp/qs-bar.sock`. To get live OSDs and the app
drawer, add binds like these to your Hyprland config:

```lua
-- app drawer
hl.bind("SUPER + D", hl.dsp.exec_cmd("printf 'toggle\\n' | nc -UN /tmp/qs-bar.sock"))

-- volume OSD
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && printf 'volume\\n' | nc -UN /tmp/qs-bar.sock"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && printf 'volume\\n' | nc -UN /tmp/qs-bar.sock"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && printf 'volume\\n' | nc -UN /tmp/qs-bar.sock"),     { locked = true, repeating = true })

-- brightness OSD
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && printf 'brightness\\n' | nc -UN /tmp/qs-bar.sock"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && printf 'brightness\\n' | nc -UN /tmp/qs-bar.sock"), { locked = true, repeating = true })

-- screenshots (optional)
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("mkdir -p \"$HOME/Pictures\"; grim -g \"$(slurp)\" - | tee \"$HOME/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png\" | wl-copy"))
hl.bind("Print",              hl.dsp.exec_cmd("mkdir -p \"$HOME/Pictures\"; grim \"$HOME/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png\""))
```

---

## Common Commands

The bar listens on `/tmp/qs-bar.sock`. Send commands with:

```sh
printf 'toggle\n' | nc -UN /tmp/qs-bar.sock    # toggle app drawer
printf 'volume\n' | nc -UN /tmp/qs-bar.sock    # show volume OSD
printf 'brightness\n' | nc -UN /tmp/qs-bar.sock# show brightness OSD
printf 'view0\n' | nc -UN /tmp/qs-bar.sock     # open notch view 0 (workspaces)
printf 'view1\n' | nc -UN /tmp/qs-bar.sock     # 1 = media
printf 'view2\n' | nc -UN /tmp/qs-bar.sock     # 2 = timer
printf 'view3\n' | nc -UN /tmp/qs-bar.sock     # 3 = wallpaper picker
printf 'view4\n' | nc -UN /tmp/qs-bar.sock     # 4 = notification centre
printf 'view5\n' | nc -UN /tmp/qs-bar.sock     # 5 = control center
printf 'wifi\n' | nc -UN /tmp/qs-bar.sock      # open Wi-Fi menu
printf 'bluetooth\n' | nc -UN /tmp/qs-bar.sock # open Bluetooth menu
printf 'collapse\n' | nc -UN /tmp/qs-bar.sock  # collapse the notch
```

These are handy for scripting, screencapturing, or binding to custom keys.

---

## Configuration

- **Colors/fonts** — edit `shell.qml`, `ControlCenter.qml`, `ConnectivityMenu.qml`,
  etc. All colors are inline hex values.
- **Wallpaper directory** — set `wallpaperDir` in `WallpaperPicker.qml`
  (defaults to `~/Pictures/walls`).
- **Workspaces shown** — see `wsList` in `shell.qml`.

---

## Troubleshooting

- **No volume/brightness control** — make sure `wpctl` / `brightnessctl` are installed
  and your user is in the `video` group (NixOS: udev rule above).
- **Bluetooth won't pair** — the bar uses `bluetoothctl` (its own agent). Make sure
  `bluez` is installed and bluetooth is enabled.
- **Cover art / app icons missing** — icons are resolved from the hicolor theme at
  `/run/current-system/sw/share/icons/hicolor/128x128/apps/` (adjust the path in
  `WsPreview.qml` / `CoverArt.qml` for other distros).

---

## Contributing

PRs, ideas, and bug reports welcome. Please keep changes focused and test them before
opening a PR.

## Acknowledgments

This project was developed with the assistance of LLMs (AI code assistants). I only
provided the prompts and design direction; the implementation, debugging, and
iteration were carried out by the AI.

- [**enhaoswen/Tide-island**](https://github.com/enhaoswen/Tide-island) — control
  center layout, slider styling, Dynamic Island ergonomics (GPL-3.0).
- **@end-4** — workspace overview design inspiration.
- [**Quickshell**](https://github.com/quickshell/quickshell) — the shell runtime.

---

Made for Wayland users who like quiet, practical desktops.
