{
  description = "Haskell FFI binding to CUDA";

  inputs = {

    haedosa.url = "github:haedosa/flakes";
    nixpkgs.follows = "haedosa/nixpkgs";
    flake-utils.follows = "haedosa/flake-utils";

  };

  outputs =
    inputs@{ self, nixpkgs, flake-utils, ... }:
    {

      overlay = import ./overlay.nix;

    } // flake-utils.lib.eachDefaultSystem (system:

      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
          overlays = [ self.overlay ];
        };

      in rec {

        devShells.default = import ./develop.nix { inherit pkgs; };
        packages.default = pkgs.haskellPackages.cuda;
      }
    );

}
