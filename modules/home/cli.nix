# Terminal environment shared by the ThinkPad and the Mac mini (home-manager).
# Desktop bits (niri, Quickshell, GTK, ghostty itself) stay in configuration.nix.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # files: yazi (TUI file manager), lazygit
    yazi lazygit
    fzf ripgrep fd jq
    # agent multiplexer: the server runs on the mini, the ThinkPad attaches with `herdr --remote`
    herdr
  ];

  # Self-updating installs live in ~/.local/bin (Claude Code's native installer: ~/.local/bin/claude).
  # mise's shims make node/pnpm visible to non-interactive processes too (Claude Code plugin hooks, scripts),
  # which the interactive `mise activate` hook never reaches
  home.sessionPath = [ "$HOME/.local/bin" "$HOME/.local/share/mise/shims" ];

  # The `xfer` skill, so agents on both machines know about it (a symlink into the nix store)
  home.file.".claude/skills/xfer/SKILL.md".source = ../../dotfiles/claude/xfer/SKILL.md;

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
