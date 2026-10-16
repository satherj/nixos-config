{ lib, writeShellApplication, jq, coreutils, procps, gnugrep, findutils, niri, dconf }:

# `theme`: renders themes/*.json through themes/templates/* into ghostty, niri, GTK3/4 (css + settings.ini), zathura, and the system light/dark scheme (dconf)
# and $XDG_STATE_HOME/theme/colors.env. Presets and templates are baked in from the repo.
writeShellApplication {
  name = "theme";
  runtimeInputs = [ jq coreutils procps gnugrep findutils niri dconf ];
  text = builtins.replaceStrings [ "@themes@" ] [ "${../themes}" ] (builtins.readFile ./theme.sh);
}
