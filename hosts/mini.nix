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
      # ThinkPad
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkAUlqGrJp8GBhDTXPyqz5ejkjG9YQ7J5q92XFe0drj"
    ];
  };
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git curl rsync tmux btop
    # Claude Code plugins (security-guidance) need a real python3; /usr/bin/python3 is only the Xcode CLT stub
    python3
    # dev stacks: `wt` (fondaro-mono/scripts/wt, always the main checkout's) drives process-compose per slot
    process-compose
    (writeShellScriptBin "wt" ''
      exec "$HOME"/Developer/fondaro-mono/scripts/wt "$@"
    '')
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

  # cloudflared: https://tunnel.fondaro.com -> the dev API, for clients that can't be on Tailscale
  # (Zapier, the Android debug build, Twilio). Only that hostname is routed, everything else gets a 404.
  # The credentials JSON stays in ~/.cloudflared (chmod 600, never in this public repo); cert.pem is not
  # needed to run a tunnel, only to create or route one (`cloudflared tunnel login` fetches it again).
  environment.etc."cloudflared/config.yml".text = ''
    tunnel: 996b297a-f9a0-4721-85f5-38990859e4a6
    credentials-file: /Users/mac-mini/.cloudflared/996b297a-f9a0-4721-85f5-38990859e4a6.json
    no-autoupdate: true
    ingress:
      - hostname: tunnel.fondaro.com
        service: http://127.0.0.1:3001
      - service: http_status:404
  '';
  # Runs as you (not root) from login; `launchctl kickstart -k gui/501/org.cloudflare.cloudflared` restarts it
  launchd.user.agents.cloudflared = {
    serviceConfig = {
      Label = "org.cloudflare.cloudflared";
      ProgramArguments = [ "${pkgs.cloudflared}/bin/cloudflared" "tunnel" "--config" "/etc/cloudflared/config.yml" "run" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/mac-mini/Library/Logs/cloudflared.log";
      StandardErrorPath = "/Users/mac-mini/Library/Logs/cloudflared.log";
    };
  };

  # herdr server, always up from login, so `herdr --remote mini` from the ThinkPad always finds it.
  # Started through a fish login shell: launchd's bare environment would leave panes without the
  # nix PATH, SHELL and mise. Logs: ~/.config/herdr/herdr-server.log. Versions come from nix, not `herdr update`.
  launchd.user.agents.herdr = {
    serviceConfig = {
      Label = "org.herdr.server";
      ProgramArguments = [ "/run/current-system/sw/bin/fish" "-l" "-c" "exec ${pkgs.herdr}/bin/herdr server" ];
      EnvironmentVariables.SHELL = "/run/current-system/sw/bin/fish";
      WorkingDirectory = "/Users/mac-mini";
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/mac-mini/Library/Logs/herdr-launchd.log";
      StandardErrorPath = "/Users/mac-mini/Library/Logs/herdr-launchd.log";
    };
  };

  # Postgres for the dev stacks: same major version as production (17), with the extensions the
  # schema uses. `fondaro_golden` is a template database; each worktree gets its own clone.
  # Localhost only, and trust auth: a single-user dev box nothing else can reach.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17.withPackages (p: [ p.postgis p.pgvector ]);
    # runs as the user (launchd agent), so the data lives in the home folder
    dataDir = "/Users/mac-mini/.local/share/postgresql/17";
    authentication = ''
      local all all              trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
    '';
    settings = {
      max_connections = 200;
      shared_buffers = "512MB";
    };
  };
  launchd.user.agents.postgresql.serviceConfig = {
    StandardOutPath = "/Users/mac-mini/Library/Logs/postgresql.log";
    StandardErrorPath = "/Users/mac-mini/Library/Logs/postgresql.log";
  };

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
