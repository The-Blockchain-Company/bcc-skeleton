{ system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
, sourcesOverride ? {}
}:
let
  sources = import ./sources.nix { inherit pkgs; }
    // sourcesOverride;
  iohKNix = import sources.tbco-nix {};
  haskellNix = import sources."haskell.nix";
  # use our own nixpkgs if it exist in our sources,
  # otherwise use tbcoNix default nixpkgs.
  nixpkgs = sources.nixpkgs or
    (builtins.trace "Using IOHK default nixpkgs" iohKNix.nixpkgs);

  # for inclusion in pkgs:
  overlays =
    # Haskell.nix (https://github.com/input-output-hk/haskell.nix)
    haskellNix.overlays
    # haskell-nix.haskellLib.extra: some useful extra utility functions for haskell.nix
    ++ iohKNix.overlays.haskell-nix-extra
    # tbcoNix: nix utilities and niv:
    ++ iohKNix.overlays.tbcoNix
    # our own overlays:
    ++ [
      (pkgs: _: with pkgs; {

        # commonLib: mix pkgs.lib with tbco-nix utils and our own:
        commonLib = lib // tbcoNix
          // import ./util.nix { inherit haskell-nix; }
          # also expose our sources and overlays
          // { inherit overlays sources; };

        # Example of using a package from tbco-nix
        # TODO: Declare packages required by the build.
        inherit (tbcoNix.jormungandrLib.packages.release) jormungandr;
      })
      # Our haskell-nix-ified cabal project:
      (import ./pkgs.nix)
    ];

  pkgs = import nixpkgs {
    inherit system crossSystem overlays;
    config = haskellNix.config // config;
  };

in pkgs
