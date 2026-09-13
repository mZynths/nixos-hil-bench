{ config, pkgs, ... }:

let
  binaryNinjaFree = pkgs.callPackage ./binaryninja-free.nix { };
  eim = pkgs.callPackage ./eim.nix { };
  tmog = pkgs.callPackage ./tmog.nix { };
in
{
  # vscode and Binary Ninja (free) are proprietary/unfree packages
  nixpkgs.config.allowUnfree = true;

  # Localization & Time
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Window Manager & Remote Display
  programs.niri.enable = true;
  hardware.uinput.enable = true;

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

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

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

  programs.zsh.ohMyZsh = {
    enable = true;
    # zsh-autosuggestions and fzf match the Mac's actual .zshrc; git/sudo/direnv
    # are kept from the original blueprint.
    plugins = [ "git" "sudo" "direnv" "zsh-autosuggestions" "fzf" ];
    theme = "zynths-catppu";
  };

  # home-manager: manages everything symlinked into zynths' $HOME.
  # (home.file is a home-manager option, not a plain NixOS one — it has to
  # live under home-manager.users.<name>, not at the top level.)
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.zynths = {
    home.stateVersion = "24.05";

    # Symlink custom Zsh theme
    home.file.".oh-my-zsh/custom/themes/zynths-catppu.zsh-theme".source = ../../files/zsh-themes/zynths-catppu.zsh-theme;

    # zsh-autosuggestions isn't a stock oh-my-zsh plugin, so its package's
    # plugin directory has to be symlinked into custom/plugins/ for the
    # plugins=(...) list above to find it.
    home.file.".oh-my-zsh/custom/plugins/zsh-autosuggestions".source =
      "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";

    # Symlink Zsh dependencies (~/.zsh/*), sourced by .zshrc
    home.file.".zsh/aliases.zsh".source = ../../files/zsh/aliases.zsh;
    home.file.".zsh/functions.zsh".source = ../../files/zsh/functions.zsh;
    home.file.".zsh/themes.zsh".source = ../../files/zsh/themes.zsh;

    # Niri config (window rules, binds, and the wallpaper spawn-at-startup below)
    home.file.".config/niri/config.kdl".source = ../../files/niri/config.kdl;

    # Wallpaper, referenced by files/niri/config.kdl's swaybg spawn-at-startup
    home.file."wallpapers/Jelly Wish.png".source = (../../wallpapers) + "/Jelly Wish.png";

    # Terminal configs — both default to zsh, matching the Mac setup
    home.file.".config/foot/foot.ini".source = ../../files/foot/foot.ini;
    home.file.".config/kitty/kitty.conf".source = ../../files/kitty/kitty.conf;
  };

  # Cloud Storage Automounts (Google Drive & iCloud)
  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    rclone
    swaybg      # wallpaper daemon for niri
    alacritty   # bound to Mod+T in files/niri/config.kdl
    foot
    kitty
    google-chrome
    tmog
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
