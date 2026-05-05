{ self, ... }: {
  flake.homeManagerModules.default = { config, lib, pkgs, ... }: with lib;
  let
    cfg = config.programs.gsd;
    sys = pkgs.stdenv.hostPlatform.system;

    pkgFor = {
      "claude-code" = self.packages.${sys}.claude-code;
      "codex"       = self.packages.${sys}.codex;
      "copilot"     = self.packages.${sys}.copilot;
    };

    gsdFlag = {
      "claude-code" = "--claude";
      "codex"       = "--codex";
      "copilot"     = "--copilot";
    };
  in {
    imports = [ ../hm/vault.nix ];

    options.programs.gsd = {
      enable = mkEnableOption "GSD multi-runtime AI tooling";

      gsdPackage = mkOption {
        type    = types.package;
        default = self.packages.${sys}.gsd-cc;
        description = "The get-shit-done-cc derivation to run on activation.";
      };

      providers = mkOption {
        type    = types.listOf (types.enum [ "claude-code" "codex" "copilot" ]);
        default = [];
        description = "AI runtimes to install (binary + GSD config).";
      };

      minimal = mkOption {
        type    = types.bool;
        default = false;
        description = "Pass --minimal to GSD (reduces 86 skills → 6).";
      };
    };

    config = mkIf cfg.enable {
      home.packages = map (p: pkgFor.${p}) cfg.providers;

      home.activation = mkMerge (map (provider:
        let minFlag = optionalString cfg.minimal " --minimal"; in {
          "gsd-install-${provider}" = hm.dag.entryAfter [ "linkGeneration" ] ''
            # Detach stdin so GSD's installer always takes the
            # non-interactive path regardless of how activation was
            # invoked (build-profiles attaches the user's tty, which
            # makes GSD prompt despite --yes).
            $DRY_RUN_CMD ${cfg.gsdPackage}/bin/get-shit-done-cc ${gsdFlag.${provider}}${minFlag} --global --yes < /dev/null || true
          '';
        }
      ) cfg.providers);
    };
  };
}
