{
  description = "[WIP] Nix Flake for building WSL2 kernels (arm64/x86_64)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }@inputs:
    let
      supportedSystems = [
        # "aarch64-linux" # TODO: Test on ARM64 Windows?
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems
      (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        allKernels = with builtins; map (k: getAttr k self.packages.${system}) (attrNames self.packages.${system});

        devShell = pkgs.mkShell {
          name = "devShell";
          inherit (self.checks.${system}.pre-commit-checks) shellHook;
          buildInputs = with pkgs;
            [
              zlib
            ]
            ++ self.checks.${system}.pre-commit-checks.enabledPackages;
          inputsFrom = allKernels;
        };
      in
      {
        devShells = {
          default = devShell;
        };

        packages = {
          wsl2-linux-kernel-with-zfs = pkgs.callPackage ./packages/wsl2-linux-kernel-with-zfs { };
        };
        # for `nix fmt`
        formatter = (inputs.treefmt-nix.lib.evalModule pkgs ./nix/formatter.nix).config.build.wrapper;
        # for `nix flake check`
        checks = {
          formatting = (inputs.treefmt-nix.lib.evalModule pkgs ./nix/formatter.nix).config.build.wrapper;
        } // {
          pre-commit-checks = import ./nix/pre-commit-checks.nix {
            inherit
              self
              system
              inputs;
            inherit (nixpkgs) lib;
          };
        };

      }) // {
      overlays.default = final: _: {
        inherit (self.packages.${final.system}) wsl2-linux-kernel-base wsl2-linux-kernel-with-zfs;
      };
    };
}
