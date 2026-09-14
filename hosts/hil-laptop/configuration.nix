{ config, lib, pkgs, ... }:

let
  binaryNinjaFree = pkgs.callPackage ./binaryninja-free.nix { };
  eim = pkgs.callPackage ./eim.nix { };
  tmog = pkgs.callPackage ./tmog.nix { };

  # programs.zsh.ohMyZsh only sets ZSH_CUSTOM if its own `custom` option is
  # given a Nix-built path — home-manager symlinks into ~/.oh-my-zsh/custom
  # are never read otherwise (ZSH_CUSTOM falls back to a path inside the
  # read-only Nix store). Build a proper custom dir instead.
  ohMyZshCustom = pkgs.linkFarm "oh-my-zsh-custom" [
    { name = "themes/zynths-catppu.zsh-theme"; path = ../../files/zsh-themes/zynths-catppu.zsh-theme; }
    { name = "plugins/zsh-autosuggestions"; path = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions"; }
  ];
in
{
  # vscode and Binary Ninja (free) are proprietary/unfree packages
  nixpkgs.config.allowUnfree = true;

  # Bootloader (UEFI via systemd-boot; the disk has a dedicated FAT32 ESP)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # waybar's icon glyphs (battery/volume/network) are Nerd Font private-use
  # codepoints — without this they render as blank boxes.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Localization & Time
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Window Manager & Remote Display
  # Nothing previously launched niri on boot — programs.niri.enable only
  # makes it available, it doesn't start a session. Auto-login straight
  # into niri (no separate greeter) since Sunshine needs an active
  # graphical session to stream, and this is a single-user bench anyway.
  programs.niri.enable = true;
  hardware.uinput.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = "zynths";
    };
  };

  # NixOS otherwise injects a stripped PATH via Environment= on the niri.service
  # unit which shadows the imported user-manager PATH. Disabling the default
  # lets niri inherit the full PATH set up by niri-session.
  systemd.user.services.niri.enableDefaultPath = false;

  # Compressed RAM-backed swap, first line of defense before the disk swapfile
  zramSwap.enable = true;

  # Containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # `docker` aliases to podman
  };

  # Sandboxing (ad-hoc crackme containment, not a real security boundary)
  programs.firejail.enable = true;

  # Packet capture
  programs.wireshark.enable = true; # sets up dumpcap capabilities for non-root capture

  # Remote shell access (server); openssh package below covers the client (ssh, scp, sftp)
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # Reach the bench from anywhere without port-forwarding/dynamic-IP hassle.
  # One-time manual step after rebuild: sudo tailscale up
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # Networking — zynths was already in the "networkmanager" group below, but
  # the service itself was never enabled, so there was no daemon to
  # associate with WiFi at all on a fresh install.
  networking.networkmanager.enable = true;
  networking.hostName = "darth-vader"; # matte black Thinkpad, classic red dot

  # Role-Based Access Control
  users.groups.plugdev = {};
  users.users.zynths = {
    isNormalUser = true;
    extraGroups = [ "wheel" "dialout" "plugdev" "networkmanager" "wireshark" ];
  };

  # Hardware Udev Rules for Embedded Dev
  # platformio-core.udev covers the long tail of common board/programmer
  # VID:PIDs (Arduino, ESP32 boards, ST-LINK, J-Link, etc.) so new boards
  # generally don't need a hand-added rule below.
  services.udev.packages = with pkgs; [ platformio-core.udev openocd ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3748", MODE="660", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="374b", MODE="660", GROUP="plugdev"
    SUBSYSTEM=="tty", KERNEL=="ttyUSB*", MODE="660", GROUP="plugdev"
    SUBSYSTEM=="tty", KERNEL=="ttyACM*", MODE="660", GROUP="plugdev"
  '';

  # Shell Environment & Zsh
  programs.nix-ld.enable = true;
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # ohMyZsh.plugins below references "direnv", but that only wires the shell
  # hook -- the actual binary was never installed, which means the entire
  # project-level-dependency workflow in docs/dependency-scope.md has never
  # actually worked. nix-direnv caches flake evaluations for faster reloads.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zsh.ohMyZsh = {
    enable = true;
    # zsh-autosuggestions and fzf match the Mac's actual .zshrc; git/sudo/direnv
    # are kept from the original blueprint.
    plugins = [ "git" "sudo" "direnv" "zsh-autosuggestions" "fzf" ];
    theme = "zynths-catppu";
    custom = "${ohMyZshCustom}";
  };

  # aliases.zsh/functions.zsh/themes.zsh are symlinked into ~/.zsh/ below via
  # home-manager, but nothing sources them without this — there's no
  # ~/.zshrc doing the [ -f ~/.zsh/foo.zsh ] && source ... that the original
  # Mac setup relied on. mkAfter ensures this runs after oh-my-zsh loads
  # (matching "aliases/functions override omz, not the other way").
  programs.zsh.interactiveShellInit = lib.mkAfter ''
    [ -f ~/.zsh/aliases.zsh ] && source ~/.zsh/aliases.zsh
    [ -f ~/.zsh/functions.zsh ] && source ~/.zsh/functions.zsh
    [ -f ~/.zsh/themes.zsh ] && source ~/.zsh/themes.zsh
  '';

  # home-manager: manages everything symlinked into zynths' $HOME.
  # (home.file is a home-manager option, not a plain NixOS one — it has to
  # live under home-manager.users.<name>, not at the top level.)
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # A function (not a plain attrset) so this submodule gets home-manager's
  # own extended lib (needed for lib.hm.dag.entryAfter below) rather than
  # just closing over the outer NixOS module's plain nixpkgs lib.
  home-manager.users.zynths = { lib, pkgs, ... }: {
    home.stateVersion = "24.05";

    # macOS-style GTK theme/icons/cursor (KiCad and other GTK/wxWidgets apps
    # were rendering with plain Adwaita — GTK's own default — since nothing
    # had ever set a theme).
    gtk = {
      enable = true;
      theme = {
        name = "WhiteSur-Dark";
        package = pkgs.whitesur-gtk-theme;
      };
      iconTheme = {
        name = "WhiteSur-dark";
        package = pkgs.whitesur-icon-theme;
      };
    };

    home.pointerCursor = {
      name = "WhiteSur-cursors";
      package = pkgs.whitesur-cursors;
      size = 24;
      gtk.enable = true;
    };

    # Symlink Zsh dependencies (~/.zsh/*), sourced via programs.zsh.interactiveShellInit above
    home.file.".zsh/aliases.zsh".source = ../../files/zsh/aliases.zsh;
    home.file.".zsh/functions.zsh".source = ../../files/zsh/functions.zsh;
    home.file.".zsh/themes.zsh".source = ../../files/zsh/themes.zsh;

    # Niri config (window rules, binds, and the wallpaper spawn-at-startup below)
    home.file.".config/niri/config.kdl".source = ../../files/niri/config.kdl;

    # monitor.kdl (included by config.kdl above) must be a plain writable
    # file, not a home.file symlink -- nwg-displays owns it entirely and
    # rewrites it on every Apply. Only create it if missing, so nwg-displays'
    # own writes survive across rebuilds instead of being reset each time.
    home.activation.ensureNiriMonitorKdl = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config/niri"
      [ -f "$HOME/.config/niri/monitor.kdl" ] || touch "$HOME/.config/niri/monitor.kdl"
    '';

    # Thin macOS-style top bar, Catppuccin Mocha themed
    home.file.".config/waybar/config.jsonc".source = ../../files/waybar/config.jsonc;
    home.file.".config/waybar/style.css".source = ../../files/waybar/style.css;

    # Wallpaper, referenced by files/niri/config.kdl's swaybg spawn-at-startup
    home.file."wallpapers/Jelly Wish.png".source = (../../wallpapers) + "/Jelly Wish.png";

    # Terminal configs — all three default to zsh and share the Catppuccin
    # Mocha palette; kitty is the themed default (Mod+T), the other two are
    # kept installed and themed too rather than trimmed.
    home.file.".config/foot/foot.ini".source = ../../files/foot/foot.ini;
    home.file.".config/kitty/kitty.conf".source = ../../files/kitty/kitty.conf;
    home.file.".config/alacritty/alacritty.toml".source = ../../files/alacritty/alacritty.toml;
  };

  # Cloud Storage Automounts (Google Drive & iCloud)
  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    rclone
    swaybg      # wallpaper daemon for niri
    alacritty
    foot
    kitty       # bound to Mod+T in files/niri/config.kdl
    google-chrome
    tmog

    # niri's default config.kdl references these directly (launcher, locker,
    # bar, media/brightness keys) but none of them were ever installed
    fuzzel        # Mod+D app launcher
    swaylock      # Super+Alt+L screen locker
    waybar        # status bar, spawn-at-startup
    wireplumber   # wpctl, volume keys (already present transitively, kept explicit)
    playerctl     # media keys
    brightnessctl # brightness keys
    pavucontrol   # waybar's pulseaudio module click-through
    nwg-displays  # GUI display arrangement; writes changes into niri's config.kdl
                  # (unlike wdisplays, which only applies them transiently)
    openssh     # ssh/scp/sftp client — services.openssh already puts this on PATH, listed explicitly anyway
    bubblewrap
    wireshark

    # RE / binary analysis
    ghidra
    binaryNinjaFree
    radare2
    cutter
    imhex
    hexyl       # CLI hex viewer, complements imhex for SSH/scripted use
    binwalk

    # Embedded / hardware toolchain
    kicad
    ngspice     # also the sim engine behind KiCad's built-in schematic simulator
    # qucs-s    # dedicated schematic-capture simulator (ngspice/Xyce backend);
                # uncomment if an actual RF/S-parameter/harmonic-balance project
                # shows up — KiCad+ngspice above doesn't cover that, QUCS-S does
    eim         # ESP-IDF Installation Manager
    openocd
    stlink      # st-flash, st-info, st-util
    dfu-util
    esptool
    avrdude     # classic AVR/Arduino (Uno, Nano, ...) flashing
    platformio-core  # CLI only — VS Code IDE integration is project-level, see docs/dependency-scope.md
    tio
    picocom
    serial-studio # real-time serial plotting/dashboard
    sigrok-cli
    pulseview
    can-utils
    usbutils    # lsusb

    # WebSocket client (ad hoc / scripted use)
    websocat

    # Languages
    git
    rustc
    cargo
    go
    go-task

    # Process / resource monitoring
    htop        # process list/search/kill
    btop        # resource graphs, local
    bottom      # resource graphs, alt layout
    glances     # resource graphs, has a -w web-dashboard mode for remote checks

    # General dev tooling
    vscode      # codef ("code" cli)
    claude-code
    python3     # json
    fzf         # cdf, codef
    ffmpeg      # extract_audio
    audacity    # audio recording/editing, pairs with the audio-electronics work
    micromamba  # mamba-family env manager for the python-envs/ specs

    # Documentation
    texlive.combined.scheme-medium  # xelatex
  ];

  systemd.user.services.mount-gdrive = {
    description = "Mount Google Drive";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/GoogleDrive";
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive: %h/GoogleDrive --vfs-cache-mode full --vfs-refresh --no-modtime";
      ExecStop = "/run/wrappers/bin/fusermount -u %h/GoogleDrive";
      Restart = "on-failure"; RestartSec = "10s";
    };
  };

  systemd.user.services.mount-icloud = {
    description = "Mount iCloud Drive";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/iCloudDrive";
      ExecStart = "${pkgs.rclone}/bin/rclone mount iclouddrive: %h/iCloudDrive --vfs-cache-mode full --vfs-refresh --no-modtime";
      ExecStop = "/run/wrappers/bin/fusermount -u %h/iCloudDrive";
      Restart = "on-failure"; RestartSec = "10s";
    };
  };

  # DO NOT CHANGE: NixOS release version
  system.stateVersion = "24.05";
}
