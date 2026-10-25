# Mac mini M4: headless dev server (herdr, Claude Code sessions, worktrees, dev servers).
# No FileVault, so it logs itself in, never sleeps or locks, and comes back after a power cut.
# Auto-login itself is set once in System Settings > Users & Groups (it needs the password).
{ pkgs, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # Determinate Nix runs the daemon and owns nix.conf
  nix.enable = false;

  networking.hostName = "mini";
  networking.computerName = "mini";
  networking.localHostName = "mini";

  system.primaryUser = "mac-mini";
  users.knownUsers = [ "mac-mini" ];
  users.users.mac-mini = {
    uid = 501;
    home = "/Users/mac-mini";
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # ThinkPad (carried over from the old mini's authorized_keys)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHHGedIYaDmGzpkKl2Wy6bKGFyHBH09zcg4AujXYI5jE"
    ];
  };
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git curl rsync tmux btop
    # xterm-ghostty terminfo, so SSH sessions from ghostty on the ThinkPad render properly
    ghostty-bin.terminfo
    (writeShellScriptBin "darwin-apply" ''
      set -e
      cd "$HOME"/Developer/nixos-config
      # The ThinkPad pushes to the same repo, so start from its latest commits
      git pull -q --rebase --autostash
      # Flakes only see files git knows about, so pick up new ones before building
      git add -A
      sudo darwin-rebuild switch --flake .#mini
      # Publish to github.com/satherj/nixos-config (public!), after a gitleaks scan of the staged changes
      if ! ${gitleaks}/bin/gitleaks git --pre-commit --staged --no-banner --log-level warn .; then
        git reset -q
        echo "⚠ gitleaks flagged something above, not syncing to GitHub"
        exit 0
      fi
      git diff --cached --quiet || git commit -qm "darwin-apply $(date '+%F %R')"
      git push -q || echo "⚠ Config sync to GitHub failed (try git push in ~/Developer/nixos-config)"
    '')
  ];
  environment.variables.TERMINFO_DIRS = [ "/run/current-system/sw/share/terminfo" "/usr/share/terminfo" ];

  # Reachable over Tailscale from anywhere. tailscaled runs as a launchd daemon from boot, before login;
  # `sudo tailscale up` once after the first switch, then disable key expiry for it in the admin console.
  services.tailscale.enable = true;

  # SSH with keys only
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
    '';
  };

  # Never sleep (the display may), wake on network, restart after a power cut or freeze
  power.sleep = {
    computer = "never";
    harddisk = "never";
    display = 10;
  };
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;
  networking.wakeOnLan.enable = true;

  # Never lock: no screensaver, no password after sleep/screensaver
  system.defaults.screensaver.askForPassword = false;
  system.defaults.CustomUserPreferences."com.apple.screensaver".idleTime = 0;

  # No surprise reboots under running agents: macOS updates are installed by hand,
  # security responses and XProtect data still install automatically
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
  system.defaults.CustomSystemPreferences."/Library/Preferences/com.apple.SoftwareUpdate" = {
    CriticalUpdateInstall = true;
    ConfigDataInstall = true;
  };

  # Screen Sharing (VNC) as a GUI fallback, e.g. for a stuck dialog; connect over Tailscale
  system.activationScripts.postActivation.text = ''
    launchctl enable system/com.apple.screensharing
    launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
  '';

  system.stateVersion = 6;
}
