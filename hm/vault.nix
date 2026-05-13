{ config, lib, pkgs, ... }: with lib;
let
  cfg     = config.programs.gsd.vault;
  gsdCfg  = config.programs.gsd;

  beginMarker = "<!-- BEGIN gsd vault block -->";
  endMarker   = "<!-- END gsd vault block -->";

  vaultSection = ''
    ## Persistent memory: shmulistan vault

    A local Obsidian vault lives at `${cfg.path}`. Treat it as long-term
    memory across sessions:

    - Search the vault for relevant prior notes before answering.
    - Write reusable insights, decisions, and user preferences as new
      Zettelkasten notes — see the vault's own `CLAUDE.md` / `AGENTS.md`
      for naming + folder conventions.
    - PARA folders: ${concatStringsSep ", " [ "00_Inbox" "01_Areas" "02_Projects" "03_Resources" "04_Archive" ]}.
    - When in doubt, drop a quick note into `00_Inbox/` for later triage.
  '';

  preambleSection = optionalString (cfg.injectInstructions.preamble != "")
    "${cfg.injectInstructions.preamble}\n\n";

  vaultBlock = ''
    ${beginMarker}
    ${preambleSection}${vaultSection}${endMarker}
  '';

  instructionsRelPath = {
    "claude-code" = ".claude/CLAUDE.md";
    "codex"       = ".codex/AGENTS.md";
    "copilot"     = ".copilot/copilot-instructions.md";
  };

  declarativeProviders = gsdCfg.providers;
in {
  options.programs.gsd.vault = {
    enable = mkOption {
      type    = types.bool;
      default = true;
      description = "Integrate the vault (inject instructions into provider configs).";
    };

    path = mkOption {
      type    = types.str;
      default = "${config.home.homeDirectory}/shmulistan";
      description = "Local path to the vault.";
    };

    injectInstructions.enable = mkOption {
      type    = types.bool;
      default = true;
      description = "Append a vault-pointer block to each provider's instructions file.";
    };

    injectInstructions.preamble = mkOption {
      type    = types.lines;
      default = "";
      description = ''
        Additional markdown content prepended above the vault section
        inside the bracketed gsd block. Use it for personal policy
        (commit discipline, package conventions, session rituals) that
        applies to every runtime — claude-code, codex, and copilot.
      '';
    };
  };

  config = mkIf (gsdCfg.enable && cfg.enable && cfg.injectInstructions.enable) {
    home.file = listToAttrs (map (provider: {
      name  = instructionsRelPath.${provider};
      value = { text = vaultBlock; };
    }) declarativeProviders);
  };
}
