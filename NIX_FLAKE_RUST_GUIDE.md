## Guide: Adapting the `flake.nix` Template for Other Rust Crates

This guide explains how to adapt the provided `flake.nix` template to build your own Rust libraries and applications using Nix and `cargo2nix`. This template aims to be self-contained, avoiding the need for a local `overlay/` directory, and provides a reproducible build environment for your Rust projects.

### 1. Introduction

The `flake.nix` template you now have is configured to build Rust projects using `cargo2nix`, a tool that translates your Rust project's `Cargo.lock` into a Nix expression. This setup offers:
*   **Reproducibility:** Your builds are consistent across different environments.
*   **Isolation:** Dependencies are managed by Nix, preventing conflicts with your system.
*   **Simplified Nix Setup:** No need for complex local overlays.

### 2. Prerequisites

Before you begin, ensure you have the following:
*   **Nix:** Installed and configured with [flakes enabled](https://nixos.wiki/wiki/Flakes).
*   **A Rust Project:** Your project should have a `Cargo.toml` and a `Cargo.lock` file. Ensure your `Cargo.lock` is up-to-date by running `cargo update` in your project directory.

### 3. Step 1: Generate `Cargo.nix`

`cargo2nix` is essential for this setup. It generates a `Cargo.nix` file that describes your Rust project's dependency graph in a format Nix can understand.

1.  Navigate to the root of your Rust project.
2.  Run `cargo2nix` using `nix run`:
    ```bash
    nix run github:cargo2nix/cargo2nix -- -o Cargo.nix
    ```
    This command will create a `Cargo.nix` file in your project's root directory.
3.  **Important:** You must re-run this command every time you modify your `Cargo.toml` or `Cargo.lock` (e.g., when adding or updating dependencies).

### 4. Step 2: Create/Update `flake.nix`

Now, create a `flake.nix` file in the root of your Rust project (or update your existing one) with the following structure:

```nix
{
  inputs = {
    nixpkgs.url = "github:meta-introspector/nixpkgs?ref=feature/CRQ-016-nixify"; # Or your preferred nixpkgs branch/commit
    flake-utils.url = "github:meta-introspector/flake-utils?ref=feature/CRQ-016-nixify"; # Or a stable flake-utils URL
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.12"; # Pin to a specific release for stability
    # Add any other flake inputs your project needs, e.g., for system dependencies
    # allocator-api2.url = "github:meta-introspector/allocator-api2?ref=feature/CRQ-016-nixify";
  };

  outputs = inputs: with inputs;
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ cargo2nix.overlays.default ];
            config = {
              # Add any necessary insecure packages, e.g., for older openssl versions
              permittedInsecurePackages = [ "openssl-1.1.1w" ];
            };
          };

          # Choose your Rust toolchain.
          # Use a stable version if possible, or a specific nightly date.
          rustToolchain = pkgs.rust-bin.nightly."2025-09-16".default; # Example nightly
          # rustToolchain = pkgs.rust-bin.stable."1.81.0".default; # Example stable

          rustPkgs = pkgs.rustBuilder.makePackageSet {
            packageFun = import ./Cargo.nix; # Links to your generated Cargo.nix
            rustChannel = "nightly"; # Or "stable"
            rustVersion = "latest"; # Or a specific version like "1.81.0"

            # rootFeatures: CRUCIAL for enabling features in your workspace crates.
            # Format: "crate-name/feature-name".
            # If a feature is for the main crate, use its name.
            # Example for a crate named 'my-app' with 'std' and 'serde' features:
            # rootFeatures = [ "my-app/std" "my-app/serde" ];
            # For the 'time' crate example, we needed many features:
            rootFeatures = [
              "time/std" "time/alloc" "time/formatting" "time/parsing" "time/serde" "time/local-offset" "time/wasm-bindgen" "time/quickcheck" "time/large-dates" "time/serde-human-readable" "time/macros" "time/rand09" "time/rand08"
              "time-macros/large-dates" "time-macros/formatting" "time-macros/parsing" "time-macros/serde"
            ];

            # packageOverrides: Use this for specific overrides, e.g., linking system libraries.
            # Keep this minimal for a slim template.
            packageOverrides = pkgs: [
              (pkgs.rustBuilder.rustLib.makeOverride {
                name = "heapless";
                overrideAttrs = old: {
                  rustcBuildFlags = (old.rustcBuildFlags or [ ]) ++ [ "--allow=warnings" "--allow=dead_code" ];
                };
              })
              # Example for a crate needing a system dependency like openssl-sys
              # (pkgs.rustBuilder.rustLib.makeOverride {
              #   name = "openssl-sys";
              #   overrideAttrs = old: {
              #     nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config pkgs.openssl ];
              #   };
              # })
              # If you added allocator-api2 as an input:
              # (pkgs.rustBuilder.rustLib.makeOverride {
              #   name = "allocator-api2";
              #   overrideAttrs = old: {
              #     src = allocator-api2;
              #   };
              # })
            ];
          };

          # Development shell configuration
          workspaceShell = pkgs.mkShell {
            # Add packages you need in your development environment
            packages = [
              pkgs.statix # Example linter
              pkgs.openssl_1_1.dev # Example system library dev files
              # pkgs.rust-analyzer # For IDE support
              # pkgs.clippy
              # pkgs.rustfmt
            ];
            # Set environment variables for Rust tools
            shellHook = ''
              export PKG_CONFIG_PATH=${pkgs.openssl_1_1.dev}/lib/pkgconfig:$PKG_CONFIG_PATH
              export PATH=${rustToolchain}/bin:$PATH
            '';
          };

        in
        rec {
          # Define development shells
          devShells = {
            default = workspaceShell;
          };

          # Define packages to be built
          packages = rec {
            # Expose your workspace crates. Replace 'time' and 'timeMacros'
            # with the names of your crates as defined in their Cargo.toml.
            # For a library crate named 'my-lib':
            # myLib = rustPkgs.workspace.my-lib {};
            time = rustPkgs.workspace.time {};
            timeMacros = rustPkgs.workspace.time-macros {};

            # Expose the entire workspace for flexibility
            workspaceCrates = rustPkgs.workspace;

            # Set a default package for 'nix build'.
            # This should typically be your main library or application.
            default = time; # Replace 'time' with your default package
          };

          # Define runnable applications
          apps = rec {
            # If your project has a binary crate (e.g., src/main.rs) named 'my-app',
            # you can expose it here.
            # myApp = { type = "app"; program = "${packages.myApp}/bin/my-app"; };
            # default = myApp; # Set your main application as default
            time = { type = "app"; program = "${packages.time}/bin/time"; }; # This will likely fail for a library
            default = time; # This will likely fail for a library
          };
        }
      );
}
