# PlatformIO project template

Copy `flake.nix` and `.envrc` into a new project repo (not into
`nixos-hil-bench` — see [`../../docs/dependency-scope.md`](../../docs/dependency-scope.md)),
then:

```
direnv allow
pio-fhs   # enters the FHS-wrapped shell
code .    # launch VS Code from inside it
```

In VS Code, set in `.vscode/settings.json` (or user settings):

```json
{ "platformio-ide.useBuiltinPIOCore": false }
```

## Why this exists

The bench installs `platformio-core` system-wide for quick CLI use
(`pio run`, `pio device monitor`, etc.), and `services.udev.packages`
includes `platformio-core.udev` so common boards/programmers just work when
plugged in — no per-board udev rule needed.

The VS Code **PlatformIO IDE extension**, though, needs to invoke
`python -m platformio` itself, and manages its own downloaded toolchain
binaries that expect a standard FHS layout (`/usr/lib`, `/lib`, ...) —
neither of which lines up with how a plain system-wide Nix package works.
Per the [NixOS wiki's PlatformIO page](https://wiki.nixos.org/wiki/Platformio),
simply pointing the extension at a system PIO via
`"platformio-ide.useBuiltinPIOCore": false` is broken on current nixpkgs;
the wiki's own fix is a project-level FHS devShell, which is what this
template provides (self-authored here rather than depending on a
third-party flake, for the same reason the bench doesn't pull in random
flakes for other tools).

**Not verified end-to-end** — built from the documented pattern, not
tested on real hardware (no NixOS builder available while this template was
written). If `code .` from inside `pio-fhs` still can't run
`python -m platformio`, try adding whatever library the extension's output
panel complains about to `targetPkgs` in `flake.nix`.
