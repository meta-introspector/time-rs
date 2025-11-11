{
  description = "Nix flake for time-rs submodule";

  inputs = {
    nixpkgs.url = "github:meta-introspector/nixpkgs?ref=feature/CRQ-016-nixify";
    cargo2nix.url = "github:meta-introspector/cargo2nix?ref=feature/CRQ-016-nixify"; # Assuming this is the correct cargo2nix flake
    flake-utils.url = "github:meta-introspector/flake-utils?ref=feature/CRQ-016-nixify"; # Add flake-utils input
    time-macros = { url = "github:time-rs/time?dir=time-macros" };
  };

  outputs = { self, nixpkgs, cargo2nix, flake-utils }: 
    let
      timeRsOverlay = import ./overlay.nix;
      pkgs = import nixpkgs {
        system = "aarch64-linux";
        overlays = [ cargo2nix.overlays.default timeRsOverlay ];
      };
      rustPkgs = pkgs.rustBuilder.makePackageSet {
        packageFun = import ./Cargo.nix;
        rustChannel = "stable";
        rustVersion = "1.81.0";
        rootFeatures = [ "time-macros/large-dates" ];
      };
    in
    {
      packages.aarch64-linux.time-macros = rustPkgs.workspace.time-macros;
      defaultPackage.aarch64-linux = self.packages.aarch64-linux.time-macros;
    };
}