{
  description = "Remote HIL Bench Master Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      hil-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/hil-laptop/hardware.nix
          ./hosts/hil-laptop/configuration.nix
        ];
      };
    };
  };
}
