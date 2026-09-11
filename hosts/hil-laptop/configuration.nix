{ config, pkgs, ... }:

{
  # Localization & Time
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";
  console.keyMap = "la-latin1";

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
    theme = "zynths";
  };

  # Symlink custom Zsh theme
  home.file.".oh-my-zsh/custom/themes/zynths.zsh-theme".source = ../../files/zsh-themes/zynths.zsh-theme;

  # Cloud Storage Automounts (Google Drive & iCloud)
  programs.fuse.userAllowOther = true;
  environment.systemPackages = with pkgs; [ rclone ];

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
