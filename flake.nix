{
  description = "Typst knowledge trees development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        typst-knowledge-forests = pkgs.rustPlatform.buildRustPackage {
          pname = "typst-knowledge-forests";
          version = "0.1.0";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
          nativeCheckInputs = [ pkgs.typst pkgs.bash ];
          # Integration tests use #!/usr/bin/env bash which doesn't work in the Nix sandbox
          doCheck = false;
        };
      in
      {
        packages.default = typst-knowledge-forests;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            typst
            bashInteractive
            rustc
            cargo
            github-copilot-cli
          ];
        };
      });
}
