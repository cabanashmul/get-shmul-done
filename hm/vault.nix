{ config, lib, pkgs, ... }: with lib;
let
  cfg = config.programs.gsd.vault;
in {
  options.programs.gsd.vault = {
    enable = mkOption {
      type    = types.bool;
      default = true;
      description = "Integrate the shmulistan vault (clone + scaffold + read/write).";
    };

    path = mkOption {
      type    = types.str;
      default = "${config.home.homeDirectory}/shmulistan";
      description = "Local checkout path for the shmulistan vault.";
    };

    repoUrl = mkOption {
      type    = types.str;
      default = "git+ssh://git@github.com/shmul95/shmulistan";
      description = "Vault git remote (SSH).";
    };

    cloneIfMissing = mkOption {
      type    = types.bool;
      default = true;
      description = "git-clone the vault on activation if the path is missing.";
    };

    scaffold = mkOption {
      type    = types.bool;
      default = true;
      description = "Ensure PARA folders exist inside the vault.";
    };

    paraFolders = mkOption {
      type    = types.listOf types.str;
      default = [ "00_Inbox" "01_Areas" "02_Projects" "03_Resources" "04_Archive" ];
      description = "Folder names to create at the vault root.";
    };
  };

  config = mkIf (config.programs.gsd.enable && cfg.enable) {
    home.activation."gsd-vault-clone" = hm.dag.entryAfter [ "writeBoundary" ] (
      optionalString cfg.cloneIfMissing ''
        if [ ! -d "${cfg.path}/.git" ]; then
          $DRY_RUN_CMD ${pkgs.git}/bin/git clone ${cfg.repoUrl} "${cfg.path}" || true
        fi
      ''
    );

    home.activation."gsd-vault-scaffold" = hm.dag.entryAfter [ "gsd-vault-clone" ] (
      optionalString cfg.scaffold ''
        if [ -d "${cfg.path}" ]; then
          ${concatMapStringsSep "\n" (folder: ''
            $DRY_RUN_CMD mkdir -p "${cfg.path}/${folder}"
          '') cfg.paraFolders}
        fi
      ''
    );
  };
}
