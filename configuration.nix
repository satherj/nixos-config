# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./modules/theme.nix
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
  # mt7921 Wi-Fi power save adds bursty UDP latency/loss, which hurts WebRTC
  # (Twilio Voice) media and ICE consent checks.
  networking.networkmanager.wifi.powersave = false;

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

  # System-wide dark mode: GTK apps, libadwaita, and Chrome follow this via the Settings portal.
  # adw-gtk3 gives GTK3 apps (Chrome in GTK mode) the libadwaita look; its colours come from the active `theme` preset (gtk.css).
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "Papirus-Dark";
      cursor-theme = "macOS";
      font-name = "Inter 10";
    };
  }];
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.tailscale.enable = true;
  # Without resolved, tailscaled is the only entry in resolv.conf and returns
  # SERVFAIL ("no upstream resolvers set") whenever wifi flaps and NM's DNS is
  # briefly dropped. resolved keeps per-link DNS and fallbacks stable.
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.1" "9.9.9.9" ];
  };
  networking.networkmanager.dns = "systemd-resolved";

  fonts.packages = with pkgs; [
    maple-mono.NF
    inter
    (callPackage ./pkgs/phosphor-icons.nix { })
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

    # Prefer the external Logitech Brio (via the LG monitor's USB-C hub) over
    # the built-in camera whenever it's plugged in.
    wireplumber.extraConfig."51-prefer-brio" = {
      "monitor.v4l2.rules" = [
        {
          matches = [ { "node.description" = "~Brio.*"; } ];
          actions.update-props = {
            "priority.session" = 2000;
            "priority.driver" = 2000;
          };
        }
      ];
    };
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
    # Dotfiles live in this repo (./dotfiles) and are symlinked into ~/.config, so they stay
    # live-editable (niri hot-reloads) while being versioned. `L` never clobbers an existing path.
    "L /home/jonathans/.config/niri - - - - /home/jonathans/nixos-staging/dotfiles/niri"
    "L /home/jonathans/.config/ghostty - - - - /home/jonathans/nixos-staging/dotfiles/ghostty"
    "L /home/jonathans/.config/gtk-3.0/bookmarks - - - - /home/jonathans/nixos-staging/dotfiles/gtk-3.0/bookmarks"
    "L /home/jonathans/.config/zathura - - - - /home/jonathans/nixos-staging/dotfiles/zathura"
    "L /home/jonathans/.config/mpv - - - - /home/jonathans/nixos-staging/dotfiles/mpv"
  ];

  # Proton Drive: mounted at ~/ProtonDrive via rclone (remote "protondrive", set up with `rclone config`)
  # and shown in the Nautilus sidebar through dotfiles/gtk-3.0/bookmarks.
  # rclone's Proton library refuses to list a whole folder when any item in it is signed by a key
  # that isn't one of our addresses ("no keyring is generated"); patch it to skip those checks.
  nixpkgs.overlays = [
    (final: prev: {
      rclone = prev.rclone.overrideAttrs (old: {
        preBuild = (old.preBuild or "") + ''
          chmod -R u+w vendor/github.com/rclone
          patch -p1 -d vendor/github.com/rclone/Proton-API-Bridge < ${./patches/rclone-proton-bridge-lenient-signatures.patch}
          patch -p1 -d vendor/github.com/rclone/go-proton-api < ${./patches/rclone-go-proton-api-lenient-signatures.patch}
        '';
      });
    })
  ];
  systemd.user.services.rclone-protondrive = {
    description = "Mount Proton Drive (rclone)";
    wantedBy = [ "default.target" ];
    path = [ "/run/wrappers" ];  # rclone shells out to the setuid fusermount3 in /run/wrappers/bin
    serviceConfig = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/ProtonDrive";
      ExecStart = "${pkgs.rclone}/bin/rclone mount protondrive: %h/ProtonDrive --vfs-cache-mode full --dir-cache-time 30s --rc";  # no ChangeNotify on Proton: short cache; `rclone rc vfs/refresh recursive=true` forces a refresh
      ExecStop = "/run/wrappers/bin/fusermount3 -uz %h/ProtonDrive";
      Restart = "on-failure";
      RestartSec = 15;
    };
  };

  # Bluetooth pairing agent: without one bluez rejects pairing requests ("No agent available"),
  # so a device that lost its bond (e.g. the Pebble) loops connect/disconnect forever.
  # NoInputNoOutput = auto-accept "just works" pairing; nothing in the shell prompts for passkeys.
  systemd.user.services.bt-agent = {
    description = "Bluetooth pairing agent";
    wantedBy = [ "default.target" ];
    after = [ "dbus.socket" ];
    serviceConfig = {
      ExecStart = "${pkgs.bluez-tools}/bin/bt-agent --capability=NoInputNoOutput";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

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
  # This config is a flake (flake.nix pins nixpkgs); `nix-shell -p` / `nix run nixpkgs#…` follow the same pin
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."jonathans" = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      # Mac mini
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKvGoVcBLbdDohkyKpItuCQx9Na94bV+eSlDB0H6fzQ"
    ];
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
    ghostty quickshell swaylock swayidle xwayland-satellite wl-mirror
    # chat (Electron; runs on Wayland via NIXOS_OZONE_WL)
    slack
    # browser (replaced Helium: its WebRTC dropped Twilio calls that stock Chrome kept)
    google-chrome
    # remote desktop (unfree; outgoing connections work on Wayland, incoming control is flaky)
    anydesk
    # VNC client for the mini's macOS Screen Sharing (over Tailscale: vnc://mini); speaks Apple's auth
    remmina
    # wlsunset = night light (driven by quickshell), playerctl = media keys in niri;
    # the wallpaper is drawn by quickshell too (no swaybg)
    wlsunset playerctl
    imagemagick  # wallpaper thumbnails for the quickshell picker
    # `wallpaper-dynamic <dynamicwallpaper.club URL | .heic>` imports a time-of-day wallpaper set
    (writers.writePython3Bin "wallpaper-dynamic" { flakeIgnore = [ "E501" ]; }
      (builtins.replaceStrings [ ''"heif-dec"'' ''"magick"'' ]
        [ ''"${libheif.bin}/bin/heif-dec"'' ''"${imagemagick}/bin/magick"'' ]
        (builtins.readFile ./pkgs/wallpaper-dynamic.py)))
    # clipboard history + screen recording for the quickshell launcher / capture menu
    cliphist wf-recorder slurp grim
    gpu-screen-recorder  # single-window recording (portal window picker; wf-recorder can only do screens/regions)
    wl-clipboard brightnessctl wiremix bluetui adwaita-icon-theme
    apple-cursor  # cursors: "macOS" (black, white outline) and "macOS-White"
    # adw-gtk3 (recoloured per theme preset via gtk.css) for GTK3 apps + Papirus icons with Catppuccin folders
    adw-gtk3
    (catppuccin-papirus-folders.override { flavor = "mocha"; accent = "blue"; })
    # files: nautilus (GUI; rename/progress/conflicts stay inside its window, themed via gtk-4.0/gtk.css)
    # ffmpegthumbnailer gives it video thumbnails (images/PDFs are built in); yazi is in modules/home/cli.nix
    nautilus ffmpegthumbnailer
    fastfetch
    # `nixos-apply`: rebuild from the ~/nixos-staging flake with a live build tree (nom) and
    # package diff (nvd), push to GitHub, restart quickshell. `-l` also signs you out afterwards.
    (writeShellApplication {
      name = "nixos-apply";
      runtimeInputs = [ gitleaks nix-output-monitor nvd ];
      text = builtins.readFile ./pkgs/nixos-apply.sh;
    })
    # `xfer`: send/get files to or from the mini (pkgs/xfer.sh); `xfer-notify` is what the mini's `xfer send` calls here
    (callPackage ./pkgs/xfer.nix { peer = "mini"; })
    (writeShellApplication {
      name = "xfer-notify";
      runtimeInputs = [ libnotify ];
      text = builtins.readFile ./pkgs/xfer-notify.sh;
    })
    # files & cloud: rclone mounts Proton Drive (rclone config -> "protondrive")
    rsync rclone
    # office: lightweight word processor + spreadsheet (docx/xlsx)
    abiword gnumeric
    # PDF viewer (mupdf backend); themed in dotfiles/zathura, default for .pdf via xdg.mime below
    (zathura.override { plugins = [ zathuraPkgs.zathura_pdf_mupdf ]; })
    # video player: mpv with the uosc UI + thumbfast seek previews + mpris (playerctl/media keys);
    # config in dotfiles/mpv, colours from the `theme` command, default for video via xdg.mime below
    (mpv.override { scripts = with mpvScripts; [ uosc thumbfast mpris ]; })
    # dev tooling (git, gh, mise, fzf, lazygit, ... come from modules/home/cli.nix, shared with the mini)
    curl unzip
    # zip handling: `unzip-here <file.zip>` extracts next to the archive into a folder named after it
    # (default app for .zip via xdg.mime below); Nautilus has its own right-click Compress/Extract
    (writeShellScriptBin "unzip-here" ''
      for f in "$@"; do
        base="''${f%.*}"
        dir="$base"
        # never merge into an existing folder
        n=1
        while [[ -e "$dir" ]]; do dir="$base-$((n++))"; done
        if ${unzip}/bin/unzip -q "$f" -d "$dir"; then
          ${libnotify}/bin/notify-send -i package-x-generic "Unzipped" "$(basename "$f") → $(basename "$dir")/"
        else
          rmdir "$dir" 2>/dev/null
          ${libnotify}/bin/notify-send -u critical "Unzip failed" "$(basename "$f")"
        fi
      done
    '')
    (makeDesktopItem {
      name = "unzip-here";
      desktopName = "Unzip Here";
      exec = "unzip-here %F";
      icon = "package-x-generic";
      mimeTypes = [ "application/zip" "application/x-zip-compressed" ];
      noDisplay = true;
    })
  ];

  # Quickshell desktop shell (bar, wifi/bluetooth/battery panels, launcher, notifications).
  # QML lives next to this file in ./quickshell and is linked to /etc/quickshell;
  # niri starts it with `qs -p /etc/quickshell` and binds talk to it via `qs ipc -p /etc/quickshell ...`
  environment.etc."quickshell".source = ./quickshell;

  # Nautilus: right-click "Open in Ghostty"; trash/mounts/network locations come from gvfs below
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "ghostty";
  };
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.gnome.Nautilus.desktop";
    "application/pdf" = "org.pwmt.zathura.desktop";
    "text/html" = "google-chrome.desktop";
    "x-scheme-handler/http" = "google-chrome.desktop";
    "x-scheme-handler/https" = "google-chrome.desktop";
    "x-scheme-handler/about" = "google-chrome.desktop";
    "x-scheme-handler/unknown" = "google-chrome.desktop";
    "application/zip" = "unzip-here.desktop";
    "application/x-zip-compressed" = "unzip-here.desktop";
  } // lib.genAttrs [
    "video/mp4" "video/x-matroska" "video/webm" "video/quicktime" "video/x-msvideo"
    "video/mpeg" "video/ogg" "video/x-flv" "video/3gpp" "video/x-m4v" "video/mp2t"
  ] (_: "mpv.desktop");
  services.gvfs.enable = true;

  # Chrome has no forced theme: pick Appearance > Theme > "GTK" once and it follows the GTK
  # colours the `theme` command generates (a pinned extension theme would override every preset).

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
        a = "C-a"; # select all (no Insert-style alternative exists)
        z = "C-z"; # undo (no Insert-style alternative exists)
      };
      # Composite layer: Super+Shift held. Paste without formatting = Ctrl+Shift+V.
      settings."meta+shift".v = "C-S-v";    };
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

  # fish config (mise, zoxide, greeting) lives in modules/home/cli.nix
  programs.fish.enable = true;

  # `ssh mini`: the Mac mini dev server over Tailscale (MagicDNS)
  home-manager.users.jonathans.programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings.mini = {
      HostName = "mini";
      User = "mac-mini";
      ServerAliveInterval = 30;
    };
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

  # sshd, reachable over Tailscale only (port 22 is closed on wifi), keys only. The mini's `xfer` uses it.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "jonathans" ];
    };
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

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
