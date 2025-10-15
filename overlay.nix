self: super: {
  rustPackages = super.rustPackages.overrideAttrs (oldAttrs: {
    overrides = oldAttrs.overrides ++ [
      (final: prev: {
        time-macros = prev.time-macros.overrideAttrs (oldAttrs: {
          # Attempt to disable clippy lints or allow unknown lints
          # This might need more specific flags depending on the exact clippy version and rustc version
          # For now, let's try to add rustcBuildFlags to allow unknown lints
          rustcBuildFlags = (oldAttrs.rustcBuildFlags or []) ++ [ "--allow=unknown_lints" ];
        });
      })
    ];
  });
}