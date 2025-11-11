{
  description = "Nix flake for time-rs submodule";

  inputs = {
    nixpkgs.url = "github:meta-introspector/nixpkgs?ref=feature/CRQ-016-nixify";
    cargo2nix.url = "path:/data/data/com.termux.nix/files/home/pick-up-nix2/vendor/nix/cargo2nix";
    flake-utils.url = "github:meta-introspector/flake-utils?ref=feature/CRQ-016-nixify";
#    time-macros = { url = "github:meta-introspector/time-rs?ref=feature/CRQ-016-nixify"; };
  };

  outputs = { self, nixpkgs, cargo2nix, flake-utils }: 
    let
      pkgs = import nixpkgs {
        system = "aarch64-linux";
        overlays = [ cargo2nix.overlays.default ];
      };
      rustPkgs = pkgs.rustBuilder.makePackageSet {
        packageFun = import ./Cargo.nix;
        rustChannel = "stable";
        rustVersion = "1.81.0";
        rootFeatures = [ "time-macros/large-dates" ];
        packageOverrides = pkgs: [ # Add this block
          (pkgs.rustBuilder.rustLib.makeOverride {
            name = "time-macros";
            overrideAttrs = old: {
              rustcBuildFlags = (old.rustcBuildFlags or []) ++ [ "--allow=unknown_lints" ];
            };
          })
        ];
      };
    in
    {
      packages.aarch64-linux.time-macros = rustPkgs.workspace.time-macros { };
      defaultPackage.aarch64-linux = self.packages.aarch64-linux.time-macros { };
    };
}
