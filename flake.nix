{
  inputs = {
    nixpkgs.url = "github:meta-introspector/nixpkgs?ref=feature/CRQ-016-nixify";
    flake-utils.url = "github:meta-introspector/flake-utils?ref=feature/CRQ-016-nixify";
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12";
    allocator-api2.url = "github:meta-introspector/allocator-api2?ref=feature/CRQ-016-nixify";
  };

  outputs = inputs: with inputs;
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ cargo2nix.overlays.default ];
            config = {
              permittedInsecurePackages = [ "openssl-1.1.1w" ];
            };
          };

          rustToolchain = pkgs.rust-bin.stable."1.81.0".default;

          rustPkgs = pkgs.rustBuilder.makePackageSet {
            packageFun = import ./Cargo.nix;
            rustChannel = "nightly"; # Reverting to nightly as stable didn't fix the issue and original used nightly
            rustVersion = "latest";
            rootFeatures = [
              "time/std"
              "time/alloc"
              "time/formatting"
              "time/parsing"
              "time/serde"
              "time/local-offset"
              "time/wasm-bindgen"
              "time/quickcheck"
              "time/large-dates"
              "time/serde-human-readable"
              "time/macros"
              "time/rand09"
              "time/rand08"
              "time-macros/large-dates"
              "time-macros/formatting"
              "time-macros/parsing"
              "time-macros/serde"
            ];
            packageOverrides = pkgs: [
              (pkgs.rustBuilder.rustLib.makeOverride {
                name = "heapless";
                overrideAttrs = old: {
                  rustcBuildFlags = (old.rustcBuildFlags or [ ]) ++ [ "--allow=warnings" "--allow=dead_code" ];
                };
              })
              (pkgs.rustBuilder.rustLib.makeOverride {
                name = "allocator-api2";
                overrideAttrs = old: {
                  src = allocator-api2;
                };
              })
              (pkgs.rustBuilder.rustLib.makeOverride {
                name = "time-macros";
                overrideAttrs = old: {
                  features = [ "large-dates" "formatting" "parsing" "serde" ];
                };
              })
              (pkgs.rustBuilder.rustLib.makeOverride {
                name = "time";
                overrideAttrs = old: {
                  features = [ "std" "alloc" "formatting" "parsing" "serde" "local-offset" "wasm-bindgen" ];
                };
              })
            ];
          };

          workspaceShell = pkgs.mkShell {
            packages = [ pkgs.statix pkgs.openssl_1_1.dev ];
            shellHook = ''
              export PKG_CONFIG_PATH=${pkgs.openssl_1_1.dev}/lib/pkgconfig:$PKG_CONFIG_PATH
              export PATH=${rustToolchain}/bin:$PATH
            '';
          };

        in
        rec {
          devShells = {
            default = workspaceShell;
          };

          packages = rec {
            time = rustPkgs.workspace.time { };
            timeMacros = rustPkgs.workspace.time-macros { };
            workspaceCrates = rustPkgs.workspace;
            default = time;
          };

          apps = rec {
            time = { type = "app"; program = "${packages.time}/bin/time"; };
            default = time;
          };
        }
      );
}
