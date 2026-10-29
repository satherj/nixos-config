{ config, pkgs, ... }:

# Theme engine: presets in ./themes, rendered by the `theme` command (pkgs/theme.nix).
# Generated files live in ~/.local/state/theme (and ~/.config/gtk-{3,4}.0/gtk.css), never in the repo;
# apps that read config from the symlinked dotfiles dirs include them through the symlinks below.
let
  user = "jonathans";
  home = config.users.users.${user}.home;
  dotfiles = "${home}/nixos-staging/dotfiles";
  state = "${home}/.local/state/theme";
in
{
  environment.systemPackages = [ (pkgs.callPackage ../pkgs/theme.nix { }) ];

  systemd.tmpfiles.rules = [
    "d ${state} 0755 ${user} users -"
    # Empty placeholders so the includes below never dangle before the first `theme apply`
    "f ${state}/ghostty.conf 0644 ${user} users -"
    "f ${state}/niri.kdl 0644 ${user} users -"
    "f ${state}/zathura.conf 0644 ${user} users -"
    "f ${state}/mpv.conf 0644 ${user} users -"
    # Links from the dotfiles dirs (gitignored there) to the generated files
    "L ${dotfiles}/ghostty/theme.conf - - - - ${state}/ghostty.conf"
    "L ${dotfiles}/niri/theme.kdl - - - - ${state}/niri.kdl"
    "L ${dotfiles}/zathura/theme.conf - - - - ${state}/zathura.conf"
    "L ${dotfiles}/mpv/theme.conf - - - - ${state}/mpv.conf"
  ];
}
