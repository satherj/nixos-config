# Terminal environment shared by the ThinkPad and the Mac mini (home-manager).
# Desktop bits (niri, Quickshell, GTK, ghostty itself) stay in configuration.nix.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # files: yazi (TUI file manager), lazygit
    yazi lazygit
    fzf ripgrep fd jq
  ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting
    '';
  };

  # mise manages node, pnpm, claude-code, ... (in ~/.local/share/mise), so repos keep their pinned versions
  programs.mise.enable = true;
  programs.zoxide.enable = true;  # `z <dir>` jumps to frecent directories
  programs.helix.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "Jonathan Säther";
      # GitHub's noreply address: this repo is public and commits carry the author email
      user.email = "140653863+satherj@users.noreply.github.com";
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };
}
