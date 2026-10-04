# nixos-config

My NixOS setup. A small flake around one `configuration.nix`, no home-manager: dotfiles in [`dotfiles/`](dotfiles) are symlinked into `~/.config` so they stay live-editable.

- **Compositor:** [niri](https://github.com/YaLTeR/niri), with greetd + tuigreet for login
- **Shell:** a custom [Quickshell](https://quickshell.org) desktop in [`quickshell/`](quickshell): bar, wifi/bluetooth/audio/battery panels, launcher, notifications, OSD, lock screen, polkit dialog and wallpaper picker, all Catppuccin Mocha
- **Apps:** ghostty + fish, [Helium](https://github.com/imputnet/helium-linux) browser (packaged in [`helium.nix`](helium.nix)), yazi, Thunar

`nixos-apply` (defined in `configuration.nix`) rebuilds from this flake, restarts the shell and pushes the result here, after a gitleaks scan.
