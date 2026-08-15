{
  description = "NixOS config for nixy on my Proxmox cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    copyparty.url = "github:9001/copyparty";
  };

  outputs = { self, nixpkgs, copyparty, ... }@inputs: {
    nixosConfigurations = {
      nixy = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix

          # Copyparty!
          copyparty.nixosModules.default
          ({ pkgs, ... }: {
            nixpkgs.overlays = [ copyparty.overlays.default ];
            environment.systemPackages = [ pkgs.copyparty ];
            services.copyparty.enable = true;
          })
        ];
      };
    };
  };
}
