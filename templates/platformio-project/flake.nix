{
  description = "PlatformIO project devShell (FHS-wrapped for VS Code IDE integration)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # On NixOS, plain `platformio-core` on PATH isn't enough for the VS
      # Code PlatformIO IDE extension: it needs to invoke `python -m
      # platformio` and manages its own downloaded toolchain binaries,
      # which expect an FHS layout. Wrapping in buildFHSEnv gives it that.
      pio-fhs = pkgs.buildFHSEnv {
        name = "pio-fhs";
        targetPkgs = pkgs: with pkgs; [
          platformio-core
          python3
          git
          gcc
          zlib
          openssl
          libusb1
          ncurses
        ];
        runScript = "bash";
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pio-fhs ];
        shellHook = ''
          echo "Run 'pio-fhs' to enter the FHS shell, then 'code .' from"
          echo "inside it so the PlatformIO IDE extension can find and run"
          echo "python -m platformio correctly."
        '';
      };
    };
}
