{
  description = "Build a cargo project without extra checks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, crane, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        craneLib = crane.lib.${system};
        my-crate = craneLib.buildPackage {
          src = craneLib.cleanCargoSource (craneLib.path ./.);
          strictDeps = true;

          HASH_BUSTER = 4; # just increment this to force a rebuild

          nativeBuildInputs = with pkgs; [
            rustPlatform.bindgenHook
          ];

          buildInputs = [
            # Add additional build inputs here
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];

          preBuild = ''
            # All the `cargo:rerun-if-env-changed` env vars in https://github.com/rust-lang/rust-bindgen/blob/v0.69.4/bindgen/build.rs
            echo "LLVM_CONFIG_PATH: $LLVM_CONFIG_PATH"
            echo "LIBCLANG_PATH: $LIBCLANG_PATH"
            echo "LIBCLANG_STATIC_PATH: $LIBCLANG_STATIC_PATH"
            echo "BINDGEN_EXTRA_CLANG_ARGS: $BINDGEN_EXTRA_CLANG_ARGS"
            env | grep BINDGEN_EXTRA_CLANG_ARGS_

            # Hack to ensure that the deps crate and this crate have the same
            # value for `BINDGEN_EXTRA_CLANG_ARGS` and can thereby share the
            # prebuilt bindgen crate.
            export BINDGEN_EXTRA_CLANG_ARGS=$(echo $BINDGEN_EXTRA_CLANG_ARGS | ${pkgs.lib.getExe pkgs.gnused} 's/-frandom-seed=[^ ]\+/-frandom-seed=deadbeef/')
          '';
        };
      in
      {
        checks = {
          inherit my-crate;
        };

        packages.default = my-crate;

        apps.default = flake-utils.lib.mkApp {
          drv = my-crate;
        };

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};

          # Additional dev-shell environment variables can be set directly
          # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

          # Extra inputs can be added here; cargo and rustc are provided by default.
          packages = [
            # pkgs.ripgrep
          ];
        };
      });
}
