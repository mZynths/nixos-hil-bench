{ config, pkgs, ... }:

let
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
    extraGroups = [ "wheel" "dialout" "plugdev" "networkmanager" ];
  };

  # Hardware Udev Rules for Embedded Dev
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3748", MODE="660", GROUP="plugdev"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="374b", MODE="660", GROUP="plugdev"
    SUBSYSTEM=="tty", KERNEL=="ttyUSB*", MODE="660", GROUP="plugdev"
  '';

  # Shell Environment & Zsh
  programs.nix-ld.enable = true;
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [ "git" "sudo" "direnv" ];
    theme = "zynths-catppu";
  };

  # Symlink custom Zsh theme
  home.file.".oh-my-zsh/custom/themes/zynths-catppu.zsh-theme".source = ../../files/zsh-themes/zynths-catppu.zsh-theme;

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
