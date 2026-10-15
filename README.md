# nixos-config

My NixOS setup. A small flake around one `configuration.nix`, no home-manager: dotfiles in [`dotfiles/`](dotfiles) are symlinked into `~/.config` so they stay live-editable.

- **Compositor:** [niri](https://github.com/YaLTeR/niri), with greetd + tuigreet for login
- **Shell:** [Noctalia](https://github.com/noctalia-dev/noctalia-shell) (Quickshell-based): bar, launcher, notifications, control center, lock screen, wallpaper and OSD
- **Apps:** ghostty + fish, Google Chrome, yazi, Thunar

`nixos-apply` (defined in `configuration.nix`) rebuilds from this flake, restarts the shell and pushes the result here, after a gitleaks scan.
