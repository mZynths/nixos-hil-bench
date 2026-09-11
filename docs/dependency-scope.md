# Dependency scope: bench-level vs. project-level

Two tiers of "install this":

- **Bench-level** — lives in this repo, in `hosts/hil-laptop/configuration.nix`.
  Available in every shell, on every project, all the time. Rebuilt onto the
  bench itself; everyone touching the bench gets the same set.
- **Project-level** — lives in the *project's own repo*, loaded per-directory
  via `direnv` (already wired into this bench's zsh setup). Never touches
  this repo.

## The test

> If I opened a totally unrelated project tomorrow, would I still want this
> available in my terminal?

- **Yes** → bench-level. Things like `ghidra`, `wireshark`, `tio`, `openocd`,
  `htop`, `websocat` — you reach for these no matter what codebase you're
  in.
- **No, it's specific to what one project builds/runs** → project-level.
  Node.js for a Svelte frontend, a pinned ESP-IDF toolchain version for one
  firmware target, a Python env with that project's exact package versions.

Secondary signals, if the answer isn't obvious:

- **Does the version matter per-project?** Node majors, Python package
  versions — different projects will want different ones over time.
  Bench-level only installs one global version, so version-sensitive
  toolchains belong per-project.
- **Is it a generic, version-insensitive CLI utility?** `jq`, `curl`,
  `websocat` — fine bench-level, nobody needs a pinned version of `jq` per
  project.
- **Would this be a one-off need that never comes up again?** If so,
  project-level — otherwise `configuration.nix` slowly accumulates tools
  that only ever mattered for one thing, which is exactly the bloat this
  split exists to avoid.

## How to configure each

### Bench-level

1. Add the package to `environment.systemPackages` in
   `hosts/hil-laptop/configuration.nix` (or the relevant `programs.*` /
   `services.*` module if it needs a proper wrapper/systemd unit — see the
   README's "Custom derivations" section for the pattern used for tools not
   in nixpkgs).
2. `sudo nixos-rebuild switch --flake .#hil-laptop` on the bench.
3. Commit the change to this repo.

### Project-level

1. In the *project's own repo*, add a `flake.nix` with a
   `devShells.default` (or a plain `shell.nix`) listing exactly what that
   project needs.
2. Add a `.envrc` containing `use flake` so `direnv` auto-loads it on `cd`.
3. Run `direnv allow` once, after cloning/creating the project.
4. Commit `flake.nix` / `flake.lock` / `.envrc` to that project's repo —
   never to `nixos-hil-bench`.

## Partial exception: `python-envs/` and `templates/`

The conda/mamba env specs under `python-envs/` in *this* repo are templates,
not a bench-level install — `data-science.yml` is meant to be copied into
(or referenced by) an actual project, then created there with
`micromamba create -f <spec>.yml`. `micromamba` itself is bench-level (the
env-manager binary); the environments it creates are project-level.

Same pattern for `templates/platformio-project/` — a `flake.nix` + `.envrc`
meant to be copied into a new embedded project's own repo, not used from
here. See its README for why the VS Code PlatformIO IDE extension needs a
project-level FHS devShell rather than a bench-wide package (a specific
NixOS gotcha, not just the general bench-vs-project split).
