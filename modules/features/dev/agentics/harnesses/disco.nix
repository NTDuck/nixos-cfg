{
  ...
}: let
  discoVersion = "0.2.1";

  # https://github.com/VectorSpaceLab/AREX-Skill — DisCo CLI (@arex-skill/disco).
  # Skill-powered research agent (Creator / Researcher) built on a fork of the
  # Pi coding-agent v0.83.0. Published to npm; requires Node.js >= 22.19.0.
  disco = {
    pkgs,
    lib,
  }:
    pkgs.buildNpmPackage {
      pname = "disco";
      version = discoVersion;

      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@arex-skill/disco/-/disco-${discoVersion}.tgz";
        hash = "sha512-1+PTv5fkIctUM8HPRPGc6byMHVh5hxXLIuz5sBVrwXQPNdPqwzhBU0SZYerby7lqgRGRc4muU4pODoQ+Tl8zxg==";
      };

      npmDepsHash = "sha256-3lg2KwmoLggeRNjdRkXs+DjqXWMb/lCFY+6cazZQa58=";

      # The published tarball is prebuilt; no compilation or npm run needed.
      dontNpmBuild = true;

      # The npm package ships dist/cli.js with the `disco` bin entry.
      meta = {
        description = "DisCo: skill-powered research agent for the terminal (Creator and Researcher roles) from AREX-Skill";
        homepage = "https://github.com/VectorSpaceLab/AREX-Skill";
        license = lib.licenses.mit;
        mainProgram = "disco";
      };
    };
in {
  den.aspects.dev.agentics.harnesses.disco = {
    nixos = {pkgs, ...}: {
      environment.systemPackages = [
        (disco {
          inherit pkgs;
          inherit (pkgs) lib;
        })
      ];
    };
  };
}
