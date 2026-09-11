# Tool evaluation checklist

Working list of everything installed on the bench so far. Check a box once
you've actually used the tool and decided it earns its place; leave it
unchecked while undecided. Anything still unchecked after you've gone
through the bench is a trim candidate — remove it from
`hosts/hil-laptop/configuration.nix` and this file together.

See [`docs/dependency-scope.md`](dependency-scope.md) first if a tool turns
out to be something you only need for one project — that's a move to
project-level, not a straight cut.

## Desktop / WM

- [ ] `niri` — compositor
- [ ] `swaybg` — wallpaper daemon
- [ ] `alacritty` — terminal (bound to Mod+T)
- [ ] `foot` — terminal
- [ ] `kitty` — terminal
- [ ] `tmog` — GUI system monitor/task manager
- [ ] `google-chrome` — browser

## Remote access

- [ ] `sunshine` — remote desktop streaming (service)
- [ ] `openssh` server — remote shell (service)
- [ ] `openssh` client — ssh/scp/sftp

## Zsh / shell environment

- [ ] `zsh` + oh-my-zsh — shell
- [ ] `zynths-catppu` theme
- [ ] `nix-ld` — run non-NixOS dynamically-linked binaries

## RBAC / hardware access

- [ ] ST-LINK udev rules (`0483:3748`, `0483:374b`)
- [ ] `ttyUSB*` udev rule
- [ ] `ttyACM*` udev rule
- [ ] `platformio-core.udev` + `openocd` udev packages (broad board/programmer coverage)

## Cloud storage

- [ ] `rclone` + Google Drive automount
- [ ] `rclone` + iCloud Drive automount

## Containers / sandboxing

- [ ] `podman` (+ dockerCompat)
- [ ] `firejail`
- [ ] `bubblewrap`

## RE / binary analysis toolchain

- [ ] `ghidra`
- [ ] `binaryNinjaFree` (custom derivation)
- [ ] `radare2`
- [ ] `cutter`
- [ ] `imhex`
- [ ] `hexyl`
- [ ] `binwalk`
- [ ] `wireshark`

## Embedded / hardware toolchain

- [ ] `eim` — ESP-IDF Installation Manager (custom derivation)
- [ ] `openocd`
- [ ] `stlink` (`st-flash`, `st-info`, `st-util`)
- [ ] `dfu-util`
- [ ] `esptool`
- [ ] `avrdude`
- [ ] `platformio-core` (CLI only — see `templates/platformio-project/`)
- [ ] `tio`
- [ ] `picocom`
- [ ] `serial-studio`
- [ ] `sigrok-cli`
- [ ] `pulseview`
- [ ] `can-utils`
- [ ] `usbutils` (`lsusb`)
- [ ] `kicad`
- [ ] `ngspice` — also powers KiCad's built-in simulator
- [ ] `qucs-s` — commented out in configuration.nix, uncomment for RF/S-parameter work

## Networking / websockets

- [ ] `websocat`

## Process / resource monitoring

- [ ] `htop`
- [ ] `btop`
- [ ] `bottom`
- [ ] `glances`

## Languages / dev tooling

- [ ] `git`
- [ ] `rustc` + `cargo`
- [ ] `go`
- [ ] `go-task`
- [ ] `vscode`
- [ ] `claude-code`
- [ ] `python3`
- [ ] `fzf`
- [ ] `ffmpeg`
- [ ] `audacity`
- [ ] `micromamba`
- [ ] `texlive.combined.scheme-medium` (`xelatex`)
