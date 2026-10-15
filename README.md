# nixos-config

My NixOS setup. A small flake around one `configuration.nix`, no home-manager: dotfiles in [`dotfiles/`](dotfiles) are symlinked into `~/.config` so they stay live-editable.

- **Compositor:** [niri](https://github.com/YaLTeR/niri), with greetd + tuigreet for login
- **Shell:** a custom [Quickshell](https://quickshell.org) desktop in [`quickshell/`](quickshell): bar, wifi/bluetooth/audio/battery panels, launcher, notifications, OSD, lock screen, polkit dialog and wallpaper picker, all Catppuccin Mocha
- **Apps:** ghostty + fish, Google Chrome, yazi, Thunar

`nixos-apply` (defined in `configuration.nix`) rebuilds from this flake, restarts the shell and pushes the result here, after a gitleaks scan.

## Theming

Colour presets are JSON files in [`themes/`](themes) (palette keys = Quickshell's `Theme.qml` tokens, plus `accent`, `barOpacity`, `iconWeight`). The `theme` command (`pkgs/theme.nix`) renders them through [`themes/templates/`](themes/templates) into ghostty, niri borders, GTK3/4 and zathura, and writes the resolved preset to `~/.local/state/theme/current.json` last, which the shell watches.

```
theme list [--json]   # preset ids (or full objects)
theme set midnight    # switch + reload apps
theme next            # cycle
theme apply           # re-render the stored one (niri runs this at startup)
```

Add a preset: copy a file from `themes/` to `themes/<id>.json` (tracked, needs `nixos-apply`) or to `~/.config/theme/themes/<id>.json` (untracked, instant; wins over a built-in with the same id). Generated files never land in the repo; the dotfiles reach them through gitignored links created by `modules/theme.nix`. Running GTK and zathura windows pick up a switch on restart; the Chrome theme and Papirus folder colour are not themed.
