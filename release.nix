############################################################################
#
# Hydra release jobset.
#
# The purpose of this file is to select jobs defined in default.nix and map
# them to all supported build platforms.
#
############################################################################

# The project sources
{ Bcc ? { outPath = ./.; rev = "abcdef"; }

# Function arguments to pass to the project
, projectArgs ? {
    config = { allowUnfree = false; inHydra = true; };
    inherit sourcesOverride;
  }

# The systems that the jobset will be built for.
, supportedSystems ? [ "x86_64-linux" "x86_64-darwin" ]

# The systems used for cross-compiling
, supportedCrossSystems ? [ "x86_64-linux" ]

# A Hydra option
, scrubJobs ? true

# Dependencies overrides
, sourcesOverride ? {}

# Import pkgs, including TBCO common nix lib
, pkgs ? import ./nix { inherit sourcesOverride; }
}:

with (import pkgs.commonLib.release-lib) {
  inherit pkgs;

  inherit supportedSystems supportedCrossSystems scrubJobs projectArgs;
  packageSet = import Bcc;
  gitrev = Bcc.rev;
};

with pkgs.lib;

let
  testsSupportedSystems = [ "x86_64-linux" ];
  collectTests = ds: filter (d: elem d.system testsSupportedSystems) (collect isDerivation ds);

  inherit (systems.examples) mingwW64 musl64;

  jobs = {
    native = mapTestOn (packagePlatforms project);
    "${mingwW64.config}" = mapTestOnCross mingwW64 (packagePlatformsCross project);
  } // (mkRequiredJob (
      collectTests jobs.native.checks.tests ++
      collectTests jobs.native.benchmarks ++
      # TODO: Add your project executables to this list
      [ jobs.native.Bcc.x86_64-linux
        jobs.native.bcc-base.x86_64-linux
        jobs.native.bcc-crypto.x86_64-linux
        jobs.native.bcc-prelude.x86_64-linux
        jobs.native.bcc-ledger-specs.x86_64-linux
        jobs.native.bcc-node.x86_64-linux
        jobs.native.zerepoch.x86_64-linux
        jobs.native.Win32-network.x86_64-linux
        jobs.native.shepards.x86_64-linux
        jobs.native.tbco-monitoring-framework.x86_64-linux        
      ]
    ))
  # Build the shell derivation in Hydra so that all its dependencies
  # are cached.
  // mapTestOn (packagePlatforms { inherit (project) shell; });

in jobs
