# dotfiles-niri-dms

Portable [niri](https://github.com/YaLTeR/niri) + [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) setup for Fedora.

One-shot install on a fresh Fedora machine (e.g. t2linux):

```bash
git clone <this-repo> ~/dotfiles-niri-dms
cd ~/dotfiles-niri-dms
./bootstrap.sh
```

After it finishes, log out and pick "niri" at the display manager. On first
launch open DMS settings (`Mod+Shift+S`) and configure your displays — DMS
regenerates `~/.config/niri/dms/outputs.kdl` for your hardware.

## What's in here

```
bootstrap.sh                  one-shot installer
packages/repos.sh             enable yalter/niri, avengemedia/danklinux+dms COPRs
packages/core.txt             niri / quickshell / dms / fcitx5 / etc.
home/                         dotfile tree, rsynced into $HOME
  .config/niri/               config.kdl + DMS-managed includes (dms/*.kdl)
  .config/DankMaterialShell/  settings.json, firefox.css, themes/rosePine/
  .config/alacritty/          alacritty.toml + themes/rose-pine-moon.toml
  .config/systemd/user/dms.service.d/override.conf   sets DMS_LOCAL_PATH
  .local/share/wallpapers/rose-pine/                 ~15 wallpapers, ~27M
overlay/quickshell-dms/       local QML overrides applied on top of the
                              cp -as mirror of /usr/share/quickshell/dms/
scripts/refresh-dms-overlay.sh   run after every `dnf upgrade dms`
```

## What's *not* in here (intentional)

- HyDE: this is a niri+DMS-only repo. The original setup had HyDE Rosé Pine
  coexisting via a `shell-mode` toggle script — none of that is included.
  Bindings that referenced HyDE shell scripts (rofi launcher, swww wallpaper
  scripts, gamemode_niri.sh, keybinds_hint_niri.sh, rofi style select) were
  dropped from `config.kdl`. Audio/brightness keys were rewritten to use
  `wpctl` and `brightnessctl` instead of HyDE wrapper scripts.
- NVIDIA-only env vars (`LIBVA_DRIVER_NAME=nvidia`,
  `__GLX_VENDOR_LIBRARY_NAME=nvidia`) were removed from `config.kdl` — re-add
  them to a `~/.config/niri/local.kdl` (and `include` it from `config.kdl`)
  if the host has an NVIDIA GPU.
- Monitor-specific output config: cleared. DMS regenerates
  `dms/outputs.kdl` and the `niriOutputSettings`/`screenPreferences` blocks
  in `settings.json` once you configure displays via the DMS settings panel.

## Updating after a DMS upgrade

`/usr/share/quickshell/dms/` gains new QML files on each DMS upgrade. The
overlay at `~/.config/quickshell/dms/` won't have symlinks for them, and
`dms.service` will fail with errors like `<NewType> is not a type`. Fix:

```bash
~/dotfiles-niri-dms/scripts/refresh-dms-overlay.sh
systemctl --user restart dms.service
```

## Updating the repo from this machine's current state

When the live config diverges from the repo and you want to capture the
delta, eyeball-diff:

```bash
diff -u ~/dotfiles-niri-dms/home/.config/niri/config.kdl ~/.config/niri/config.kdl
diff -u ~/dotfiles-niri-dms/home/.config/DankMaterialShell/settings.json ~/.config/DankMaterialShell/settings.json
```

Pull selectively (don't blind-copy — re-introduces host-specific monitor
paths and absolute `/home/maverick/...` references). When pulling
`settings.json`, re-introduce the `__HOME__` placeholder for `customThemeFile`
and clear `niriOutputSettings`, `screenPreferences.{toast,notepad,osd}`,
`barConfigs[].screenPreferences`, and `lockScreenActiveMonitor`.

## Key bindings (niri+DMS)

| Key | Action |
|---|---|
| `Mod+Space` | fcitx5 IME toggle |
| `Mod+A` | DMS spotlight launcher |
| `Mod+V` | DMS clipboard manager |
| `Mod+L` | DMS lock screen |
| `Mod+X` | DMS power menu |
| `Mod+N` | DMS notification center |
| `Mod+Shift+N` | DMS notepad |
| `Mod+Shift+S` | DMS settings panel |
| `Mod+Y` / `Mod+Shift+W` | DMS wallpaper browser |
| `Mod+Alt+←/→` | DMS prev/next wallpaper |
| `Mod+Shift+T` | DMS theme light/dark toggle |
| `Mod+T` / `Mod+E` / `Mod+C` / `Mod+F` | alacritty / nautilus / zed / firefox |
| `Mod+O` / `Mod+D` | toggle overview |
| `Ctrl+Alt+W` | restart dms.service |
| `Mod+Shift+Slash` | hotkey overlay |
