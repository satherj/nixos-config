# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Boot straight into the newest generation; hold Space at power-on to get the menu
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.configurationLimit = 10;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };

  # Enable the GNOME Desktop Environment.
  # Login: greetd + tuigreet (minimal TUI greeter), no GNOME/GDM
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --user jonathans --time --remember --remember-session --asterisks --theme 'border=magenta;text=white;prompt=green;time=magenta;action=blue;button=yellow;container=black;input=white' --cmd niri-session";
      user = "greeter";
    };
  };
  programs.dconf.enable = true;

  # System-wide dark mode: GTK apps, libadwaita, and Chromium/Helium follow this via the Settings portal.
  # GTK3 apps (Thunar) get Catppuccin Mocha; libadwaita apps ignore GTK themes and just go dark.
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Catppuccin-GTK-Blue-Dark";
      icon-theme = "Papirus-Dark";
      cursor-theme = "catppuccin-mocha-mauve-cursors";
      font-name = "Inter 10";
    };
  }];
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.tailscale.enable = true;
  programs.zoxide.enable = true;  # `z <dir>` jumps to frecent directories

  fonts.packages = with pkgs; [
    maple-mono.NF
    inter
  ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  # Bluetooth (quickshell panel; bluetui = TUI behind its "More settings…")
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Battery time estimates / power profiles (quickshell battery panel)
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # ThinkPad battery care: start charging below 75%, stop at 80% (set start/end to 100 for a full charge)
  systemd.tmpfiles.rules = [
    "w /sys/class/power_supply/BAT0/charge_control_start_threshold - - - - 75"
    "w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - 80"
  ];

  # Firmware updates from LVFS (BIOS/EC/NVMe): `fwupdmgr refresh && fwupdmgr update`
  services.fwupd.enable = true;

  # No swap partition: compressed swap in RAM (50% of RAM, zstd) so big rebuilds don't OOM
  zramSwap.enable = true;

  # Keep /nix/store in check: weekly GC of generations older than 14 days, hardlink duplicates
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.settings.auto-optimise-store = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."jonathans" = {
    isNormalUser = true;
    description = "Jonathan Sather";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };


  # --- niri (Wayland compositor); pick "niri" in GDM's session menu ---
  programs.niri.enable = true;
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Lets mise-downloaded prebuilt binaries (node, etc.) run on NixOS
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # niri essentials; quickshell is the bar, launcher and notification daemon (see below)
    # swaylock stays only as an emergency fallback if the quickshell lock screen ever breaks
    ghostty quickshell swaylock swayidle xwayland-satellite
    # wlsunset = night light (driven by quickshell), playerctl = media keys in niri;
    # the wallpaper is drawn by quickshell too (no swaybg)
    wlsunset playerctl
    imagemagick  # wallpaper thumbnails for the quickshell picker
    # clipboard history + screen recording for the quickshell launcher / capture menu
    cliphist wf-recorder slurp
    wl-clipboard brightnessctl wiremix bluetui adwaita-icon-theme catppuccin-cursors.mochaMauve
    # Catppuccin Mocha for GTK3 apps + Papirus icons with Catppuccin folders
    (magnetic-catppuccin-gtk.override { accent = [ "blue" ]; })
    (catppuccin-papirus-folders.override { flavor = "mocha"; accent = "blue"; })
    # files: yazi (TUI) + thunar (GUI, programs.thunar below)
    yazi lazygit
    fastfetch
    # chat (Electron; runs on Wayland via NIXOS_OZONE_WL)
    slack
    # `nixos-apply`: copy ~/nixos-staging into /etc/nixos, rebuild, push to GitHub, restart quickshell
    # `nixos-apply -l` also signs you out afterwards, for changes that need a fresh session
    (writeShellScriptBin "nixos-apply" ''
      set -e
      sudo cp "$HOME"/nixos-staging/{configuration.nix,helium.nix} /etc/nixos/
      # --delete so files removed from staging don't linger in the deployed shell
      sudo ${rsync}/bin/rsync -a --delete "$HOME"/nixos-staging/quickshell/ /etc/nixos/quickshell/
      sudo nixos-rebuild switch
      # Publish what was just deployed to github.com/satherj/nixos-config (public!).
      # gitleaks scans the staged changes first; anything that looks like a secret blocks the sync.
      (
        cd "$HOME"/nixos-staging
        git add -A
        if ! ${gitleaks}/bin/gitleaks git --pre-commit --staged --no-banner --log-level warn .; then
          git reset -q
          echo "⚠ gitleaks flagged something above, not syncing to GitHub"
          exit 0
        fi
        { git diff --cached --quiet || git commit -qm "nixos-apply $(date '+%F %R')"; } && git push -q
      ) || echo "⚠ Config sync to GitHub failed (try git push in ~/nixos-staging)"
      if [[ "$1" == "-l" || "$1" == "--logout" ]]; then
        echo "Signing out in 3s (Ctrl+C to stay)…"
        sleep 3
        niri msg action quit --skip-confirmation
      elif pgrep -x quickshell >/dev/null; then
        pkill -x quickshell
        sleep 0.3
        qs -p /etc/quickshell -d >/dev/null
      fi
    '')
    # files & cloud: rclone mounts Proton Drive (rclone config -> "protondrive")
    rsync rclone
    fzf
    # dev tooling
    mise git gh curl unzip
    # browser (not in nixpkgs, see helium.nix)
    (callPackage ./helium.nix { })
  ];

  # Quickshell desktop shell (bar, wifi/bluetooth/battery panels, launcher, notifications).
  # QML lives next to this file in ./quickshell and is linked to /etc/quickshell;
  # niri starts it with `qs -p /etc/quickshell` and binds talk to it via `qs ipc -p /etc/quickshell ...`
  environment.etc."quickshell".source = ./quickshell;

  # Thunar with trash/mounts (gvfs) and thumbnails (tumbler)
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [ thunar-archive-plugin thunar-volman ];
  };
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # Helium is Chromium-based and reads /etc/chromium/policies: force-install Catppuccin Mocha theme
  programs.chromium = {
    enable = true;
    extensions = [ "bkkmolkhemgaeaeggcmfbghljjjoofoh" ];  # Catppuccin Chrome Theme - Mocha
  };

  # Polkit auth prompts come from quickshell (PolkitDialog.qml), not polkit-gnome.
  # The lock screen is quickshell too (Lock.qml); it checks passwords through this PAM service.
  security.pam.services.quickshell = { };

  # macOS-style clipboard keys, system-wide. Super+C/V/X become Ctrl+Insert / Shift+Insert /
  # Shift+Delete, which GUI apps and terminals (incl. ghostty) all treat as copy/paste/cut
  # without clashing with Ctrl+C = SIGINT. Other Super combos pass through to niri untouched.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.meta = {
        c = "C-insert";
        v = "S-insert";
        x = "S-delete";
      };
    };
  };

  # mise in interactive shells (node, claude-code, ... live in ~/.local/share/mise)
  programs.bash.interactiveShellInit = ''
    eval "$(${pkgs.mise}/bin/mise activate bash)"

    # Interactive terminals use fish (autosuggestions + syntax highlighting out of the box),
    # but the login shell stays bash so the niri session / scripts keep working.
    if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
      shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
      exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
    fi
  '';

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      ${pkgs.mise}/bin/mise activate fish | source
      set -g fish_greeting
    '';
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
