# nixos-hil-bench

GitOps configuration for `hil-laptop` — a NixOS Hardware-in-the-Loop bench for
embedded development, firmware/binary reverse engineering, and remote work
over Sunshine.

This README exists as a map for when you come back to refine or debug the
system. It documents *why* things are wired the way they are, and calls out
everything that hasn't been build-tested on real hardware yet.

See also:
- [`docs/dependency-scope.md`](docs/dependency-scope.md) — how to decide
  whether a new dependency belongs bench-level (this repo) or project-level
  (the project's own flake + direnv), and how to configure each.
- [`docs/tool-evaluation.md`](docs/tool-evaluation.md) — checklist for
  working through everything installed so far and trimming what doesn't
  earn its place.

## Repo layout

```
flake.nix                          entry point, defines nixosConfigurations.hil-laptop
hosts/hil-laptop/
  configuration.nix                the whole system config
  hardware.nix                     MISSING — see "Before first build" below
  binaryninja-free.nix             custom derivation, pinned + FHS-wrapped
  eim.nix                          custom derivation, pinned + autoPatchelf'd
  tmog.nix                         custom derivation, pinned static binary
files/                             tracked config content, symlinked into $HOME via home.file
  zsh-themes/zynths-catppu.zsh-theme
  zsh/{aliases,functions,themes}.zsh
  niri/config.kdl
  foot/foot.ini
  kitty/kitty.conf
  nvim/init.lua                    NOT currently wired into configuration.nix (see Gaps)
python-envs/
  data-science.yml                 micromamba/conda env spec, proof of concept
templates/
  platformio-project/              copy into a project repo, not used from here (see its README)
wallpapers/
  Jelly Wish.png                   symlinked to ~/wallpapers/, used by niri's swaybg spawn
docs/
  dependency-scope.md              bench-level vs. project-level: how to decide, how to configure each
  tool-evaluation.md               the definitive, up-to-date, categorized package list + trim checklist
```

## Before first build

`flake.nix` imports `./hosts/hil-laptop/hardware.nix`, which **does not exist
in this repo**. Generate it on the target machine and commit it:

```
sudo nixos-generate-config --show-hardware-config > hosts/hil-laptop/hardware.nix
```

Then build/switch with:

```
sudo nixos-rebuild switch --flake .#hil-laptop
```

## System basics

- **Locale/keyboard**: `en_US.UTF-8`, `console.keyMap = "us"`. Timezone is
  still `America/Mexico_City` — change if the bench moves.
- **User**: `zynths`, shell defaults to zsh, groups: `wheel`, `dialout`,
  `plugdev`, `networkmanager`, `wireshark`.
- **`nixpkgs.config.allowUnfree = true`** — required for `vscode`,
  `google-chrome`, and Binary Ninja's build inputs.

## home-manager

`flake.nix` pulls in `home-manager` as a flake input (`inputs.nixpkgs.follows`
so it shares the same nixpkgs, `home-manager.nixosModules.home-manager`
imported into the system config) and `configuration.nix` sets
`home-manager.useGlobalPkgs`/`useUserPackages`. This exists because
`home.file` — used throughout for symlinking zsh/niri/terminal configs into
`$HOME` — is a **home-manager option, not a plain NixOS one**; it has to
live under `home-manager.users.zynths = { ... };`, not at the top level of
the system config. This was wrong from the original blueprint through
several commits of this repo's history (a real bug: `nixos-rebuild switch`
would have failed outright with "the option `home.file' does not exist")
before being caught and fixed.

## Desktop: niri + Sunshine

- `programs.niri.enable` — the compositor. `files/niri/config.kdl` is
  niri's **upstream default config verbatim**, plus one added line:
  a `swaybg` `spawn-at-startup` that sets `wallpapers/Jelly Wish.png` as the
  wallpaper (niri has no built-in wallpaper support). All of niri's default
  keybinds (Mod+T terminal, Mod+Q close, workspace/column navigation, etc.)
  are intact — check the file directly rather than relying on memory of
  niri's defaults, since they can change upstream.
- Terminals: `alacritty` (bound to Mod+T by the default config), `foot`,
  and `kitty` are all installed. `foot`/`kitty` are explicitly configured
  with `shell=zsh` / `shell zsh` (`files/foot/foot.ini`,
  `files/kitty/kitty.conf`) so they match the Mac setup; `alacritty` and the
  system already default to zsh via `users.defaultUserShell`, so it needs no
  extra config.
- `services.sunshine` — remote game-streaming style desktop access,
  `capSysAdmin` + `openFirewall` enabled. This is how you're meant to reach
  the bench remotely.

## Zsh setup

Mirrors what's on the Mac, pulled from `~/.zsh/` (previously symlinks into
`~/dotfiles/zsh/`) and `~/.oh-my-zsh/custom/themes/`:

- **Theme**: `zynths-catppu` (Catppuccin Mocha prompt). The original had a
  macOS-specific `gdate`/`python3` fallback for millisecond timestamps in
  `_ms_now()` — removed here since NixOS's GNU `date` supports `%N` natively
  and the fallback was dead code on a Linux-only host.
- **Functions** (`files/zsh/functions.zsh`) — trimmed down from the original
  set. Kept: `json`, `cdf`, `codef`, `extract_audio`. Removed: `ghidra`
  (redundant — `ghidra` is a real package now), `crackenv` (Docker
  `--platform=linux/amd64` workaround for cracking x86 binaries on an ARM64
  Mac — doesn't apply, this host is native `x86_64-linux`), `serve`,
  `whisp`, `smartcomp`.
- **`aliases.zsh` — action required**: the Google Drive path alias/vars were
  redacted from a hardcoded email to `${GDRIVE_ACCOUNT}`. **You must set
  `GDRIVE_ACCOUNT` in `~/.zshrc.local`** (untracked, machine-specific) or
  the `drive` alias and `$DRIVE` var will fail with an "unset variable"
  error. Also: the *original* dotfiles had `drive` pointing at a different
  email than `$DRIVE` — looked like a stale typo on the Mac, not something
  intentional. Worth double-checking which account is correct.
- **`ohMyZsh.plugins`** is `[ "git" "sudo" "direnv" "zsh-autosuggestions" "fzf" ]`
  — `git`/`sudo`/`direnv` kept from the original blueprint, `zsh-autosuggestions`/
  `fzf` added to match what the Mac's actual `.zshrc` loads. `fzf` is a stock
  oh-my-zsh plugin (just needs the `fzf` binary, already installed);
  `zsh-autosuggestions` isn't, so its `pkgs.zsh-autosuggestions` plugin
  directory is symlinked into `~/.oh-my-zsh/custom/plugins/` via
  home-manager (see below) for oh-my-zsh's loader to find it.

## Hardware access (udev + groups)

`services.udev.extraRules` grants `plugdev` group access to:
- `0483:3748` / `0483:374b` — STMicroelectronics ST-LINK/V2 and V2-1 (JTAG/SWD
  debug probes)
- `ttyUSB*` — generic USB-serial adapters (FTDI/CH340/CP210x-style)
- `ttyACM*` — USB CDC-ACM serial (native-USB boards like Arduino Uno/Leonardo)

On top of that, `services.udev.packages = [ platformio-core.udev openocd ]`
(see "Embedded toolchain & PlatformIO" below) pulls in PlatformIO's own
curated udev ruleset, covering far more board/programmer VID:PIDs than the
hand-written rules above — the `extraRules` block is the fallback for
anything not in that curated list, not the primary mechanism.

`stlink` and `openocd` are installed specifically to pair with this. `zynths`
is in `plugdev`, `dialout`, and `wireshark` (for non-root `dumpcap` capture).

## Cloud storage automounts

`systemd.user.services.mount-gdrive` / `mount-icloud` run `rclone mount` for
`gdrive:` and `iclouddrive:` remotes on login. **`rclone config` still needs
to be run manually once** on the box to actually create those two remotes —
Nix doesn't (and shouldn't) manage rclone's OAuth tokens/config.

## Containers & sandboxing

- `virtualisation.podman` with `dockerCompat = true` — `docker` commands
  transparently map to podman. General-purpose container use (not for
  crackme isolation — see below).
- `programs.firejail.enable` and `bubblewrap` (plain package) — both
  available for ad-hoc containment when poking at untrusted binaries.
  **Neither is a real security boundary** against a binary with a kernel
  exploit; treat them as "don't let this touch my home directory by
  accident," not sandboxing against a malicious actor.

## Remote access

- `services.sunshine` — remote game-streaming style desktop access,
  `capSysAdmin` + `openFirewall` enabled.
- `services.openssh` — server, `openFirewall` enabled; `openssh` package
  covers the client (`ssh`, `scp`, `sftp`).

## Embedded toolchain & PlatformIO

- `services.udev.packages = [ platformio-core.udev openocd ]` —
  PlatformIO Core ships a curated udev ruleset covering a huge range of
  common board/programmer VID:PIDs (Arduino, ESP32 boards, ST-LINK, J-Link,
  etc.), so most new boards just work when plugged in without a hand-added
  rule. The `services.udev.extraRules` block above is a defense-in-depth
  fallback for anything not in that curated list.
- `platformio-core` is installed **bench-level as a CLI only**
  (`pio run`, `pio device monitor`, ...). The **VS Code PlatformIO IDE
  extension** is a different story: it needs to invoke `python -m
  platformio` itself and manages its own downloaded toolchain binaries that
  expect a standard FHS layout, which a plain system-wide Nix package
  doesn't provide. Per the
  [NixOS wiki](https://wiki.nixos.org/wiki/Platformio), pointing the
  extension at a system PIO via `"platformio-ide.useBuiltinPIOCore": false`
  is broken on current nixpkgs — the working fix is a project-level FHS
  devShell. `templates/platformio-project/` provides one (self-authored
  rather than depending on a third-party flake); copy it into an actual
  project repo when you start one, per
  [`docs/dependency-scope.md`](docs/dependency-scope.md).
- `avrdude` — classic AVR/Arduino (Uno, Nano, ...) flashing.

## Full package list

See [`docs/tool-evaluation.md`](docs/tool-evaluation.md) for the complete,
categorized, currently-accurate list of everything installed — it's kept in
sync as things get added/removed, so it's the source of truth rather than a
table duplicated here. Notable one-offs worth knowing about regardless:

- `binaryNinjaFree`, `eim`, `tmog` — custom derivations, see below.
- `claude-code` is from nixpkgs unstable; may lag Anthropic's latest release
  a bit since it needs a manual version/hash bump upstream — a community
  hourly-updated flake (`claude-code-nix`) exists if that ever matters.
- `micromamba` is the env-manager binary for `python-envs/` specs.

## `python-envs/`

Proof of concept for the "someday I'll have preconfigured python
environments" idea. `data-science.yml` is a conda/mamba env spec (numpy,
pandas, scipy, matplotlib, seaborn, scikit-learn, statsmodels, jupyterlab).
Create it with:

```
micromamba create -f python-envs/data-science.yml
```

Not wired into the Nix config beyond installing `micromamba` — these are
meant to be created imperatively per-project, not declared in
`configuration.nix`.

## Custom derivations (the risky part)

Three tools aren't in nixpkgs and needed one-off derivations. **None of
these have been build-tested on an actual NixOS machine** — this repo was
built on macOS, which can't run `nix build` against a Linux target. Expect
to iterate once you actually run `nixos-rebuild build` on the bench.

### `binaryninja-free.nix`
Binary Ninja Free ships as a plain zip (not a real AppImage) with a bundled
Qt6 distribution. Its binaries use standard `/lib64/ld-linux-x86-64.so.2`
interpreters and `$ORIGIN`-relative rpaths for their own bundled libs
(`plugins/libghidra.so`, `plugins/lldb/lib/*`) — confirmed by inspecting the
ELF headers directly. Wrapped with `buildFHSEnv` rather than
`autoPatchelfHook` because it's more forgiving of the many dlopen'd Qt
plugin/platform dependencies (image formats, xcb/wayland platform plugins,
etc.) that autoPatchelf can't discover by scanning `DT_NEEDED` alone.
Pinned to release `stable/6.0.10601`, sha256-verified.
**If it fails to start** with a missing-library error, add the missing
package to `targetPkgs` in the derivation.

### `eim.nix`
ESP-IDF Installation Manager CLI. Despite upstream docs claiming a static
build, the actual binary is dynamically linked (glibc, `libz`, `libgcc_s`) —
verified by inspecting its ELF dynamic section. Small enough that
`autoPatchelfHook` is the right tool here (unlike Binary Ninja, no bundled
Qt/GUI plugin mess). Pinned to `v0.1.7`, sha256-verified.

### `tmog.nix`
Turned out to need *no* patching at all: despite the `.AppImage` extension,
it's a fully static-pie ELF binary with zero dynamic dependencies (verified:
no `PT_INTERP`, no `DT_NEEDED` entries) — not actually a squashfs-based
AppImage. **No versioned or checksummed upstream release exists** — TMOG is
a solo-developer beta product with a rolling download link on `tmog.org`.
This pins whatever binary that link served at packaging time via sha256; if
tmog.org updates the file, the build will fail on a hash mismatch and the
`sha256` in `tmog.nix` will need bumping to whatever `nix build` reports as
"got:". Also worth reconsidering later whether a closed-source beta system
monitor from an indie site is something you actually want deep system
visibility from, long-term.

## Known gaps / TODO

- `hosts/hil-laptop/hardware.nix` doesn't exist — generate it on-device
  (see "Before first build").
- `files/nvim/init.lua` exists but isn't referenced anywhere in
  `configuration.nix` — no `home.file` symlink wires it into
  `~/.config/nvim/init.lua`, and `neovim` itself isn't in
  `environment.systemPackages`.
- None of the three custom derivations have been build-tested on real
  NixOS/x86_64-linux hardware.
- `templates/platformio-project/`'s FHS devShell is built from the
  documented pattern, not verified end-to-end against a real VS Code +
  PlatformIO IDE extension session.
- `GDRIVE_ACCOUNT` must be set in an untracked `~/.zshrc.local` on the
  actual machine before the `drive` alias / `$DRIVE` will work.
- `rclone config` needs to be run manually to create the `gdrive:` and
  `iclouddrive:` remotes the automount services expect.
- `ohMyZsh.plugins` doesn't match what the Mac's `.zshrc` actually loads
  (see "Zsh setup").
