{ lib, writeShellApplication, jq, coreutils, procps, gnugrep, findutils, niri }:

# `theme`: renders themes/*.json through themes/templates/* into ghostty, niri, GTK3/4, zathura
# and $XDG_STATE_HOME/theme/colors.env. Presets and templates are baked in from the repo.
writeShellApplication {
  name = "theme";
  runtimeInputs = [ jq coreutils procps gnugrep findutils niri ];
  text = builtins.replaceStrings [ "@themes@" ] [ "${../themes}" ] (builtins.readFile ./theme.sh);
}
