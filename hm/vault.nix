{ config, lib, pkgs, ... }: with lib;
let
  cfg     = config.programs.gsd.vault;
  gsdCfg  = config.programs.gsd;

  beginMarker = "<!-- BEGIN gsd vault block -->";
  endMarker   = "<!-- END gsd vault block -->";

  vaultBlock = ''
    ${beginMarker}
    ## Persistent memory: shmulistan vault

    A local Obsidian vault lives at `${cfg.path}`. Treat it as long-term
    memory across sessions:

    - Search the vault for relevant prior notes before answering.
    - Write reusable insights, decisions, and user preferences as new
      Zettelkasten notes — see the vault's own `CLAUDE.md` / `AGENTS.md`
      for naming + folder conventions.
    - PARA folders: ${concatStringsSep ", " cfg.paraFolders}.
    - When in doubt, drop a quick note into `00_Inbox/` for later triage.
    ${endMarker}
  '';

  instructionsFile = {
    "claude-code" = "${config.home.homeDirectory}/.claude/CLAUDE.md";
    "codex"       = "${config.home.homeDirectory}/.codex/AGENTS.md";
    "copilot"     = "${config.home.homeDirectory}/.copilot/copilot-instructions.md";
  };

  captureScript = pkgs.writeShellApplication {
    name = "gsd-capture-to-vault";
    runtimeInputs = with pkgs; [ jq coreutils ];
    text = builtins.readFile ../stop-hook/capture-to-vault.sh;
  };

  # Wraps capture-to-vault with vault path + inbox dir baked in via env.
  hookCommand = pkgs.writeShellApplication {
    name = "gsd-stop-hook";
    runtimeInputs = [ captureScript ];
    text = ''
      export SHMULISTAN_VAULT="${cfg.path}"
      export SHMULISTAN_INBOX="${cfg.captureHook.inboxDir}"
      exec ${captureScript}/bin/gsd-capture-to-vault "$@"
    '';
  };

  hookCmdPath = "${hookCommand}/bin/gsd-stop-hook";

  injectScript = pkgs.writeShellApplication {
    name = "gsd-vault-inject";
    runtimeInputs = [ pkgs.gnused pkgs.coreutils ];
    text = ''
      set -euo pipefail
      target="$1"
      block_file="$2"

      mkdir -p "$(dirname "$target")"

      # If target is a symlink (e.g. a stale Nix-store link from a
      # previous HM generation), replace it with a real, writable file
      # seeded from the link target's content.
      if [ -L "$target" ]; then
        seed=""
        if [ -r "$target" ]; then
          seed="$(cat "$target")"
        fi
        rm -f "$target"
        printf '%s' "$seed" > "$target"
      fi
      touch "$target"
      chmod u+w "$target"

      # Strip any existing block (idempotent).
      tmp=$(mktemp)
      sed "/${beginMarker}/,/${endMarker}/d" "$target" > "$tmp"

      # Trim trailing blank lines, then append the fresh block.
      sed -e :a -e '/^$/{$d;N;ba' -e '}' "$tmp" > "$target"
      [ -s "$target" ] && printf '\n' >> "$target"
      cat "$block_file" >> "$target"
    '';
  };
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

    injectInstructions.enable = mkOption {
      type    = types.bool;
      default = true;
      description = "Append a vault-pointer block to each provider's instructions file.";
    };

    captureHook = {
      enable = mkOption {
        type    = types.bool;
        default = true;
        description = "Wire a Stop-hook in each runtime that captures sessions to the vault inbox.";
      };

      runtimes = mkOption {
        type    = types.listOf (types.enum [ "claude-code" "codex" ]);
        default = filter (r: r != "copilot") gsdCfg.providers;
        defaultText = literalExpression "filter (r: r != \"copilot\") config.programs.gsd.providers";
        description = "Runtimes to wire the Stop hook into. Copilot is excluded — its sessionEnd has no transcript_path.";
      };

      inboxDir = mkOption {
        type    = types.str;
        default = "00_Inbox";
        description = "Vault subdirectory for captured session notes.";
      };
    };
  };

  config = mkIf (gsdCfg.enable && cfg.enable) (mkMerge [
    {
      home.activation."gsd-vault-clone" = hm.dag.entryAfter [ "linkGeneration" ] (
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
    }

    (mkIf cfg.injectInstructions.enable (
      let
        blockFile = pkgs.writeText "gsd-vault-block.md" vaultBlock;
      in {
        home.activation = listToAttrs (map (provider: {
          name  = "gsd-vault-inject-${provider}";
          value = hm.dag.entryAfter [ "gsd-install-${provider}" ] ''
            $DRY_RUN_CMD ${injectScript}/bin/gsd-vault-inject \
              "${instructionsFile.${provider}}" \
              "${blockFile}"
          '';
        }) gsdCfg.providers);
      }
    ))

    (mkIf cfg.captureHook.enable {
      home.activation = listToAttrs (map (rt:
        if rt == "claude-code" then {
          name  = "gsd-stop-hook-claude-code";
          value = hm.dag.entryAfter [ "gsd-vault-inject-claude-code" ] ''
            settings="${config.home.homeDirectory}/.claude/settings.json"
            mkdir -p "$(dirname "$settings")"
            [ -f "$settings" ] || echo '{}' > "$settings"
            tmp=$(mktemp)
            $DRY_RUN_CMD ${pkgs.jq}/bin/jq \
              --arg cmd "${hookCmdPath} claude-code" '
                .hooks //= {} |
                .hooks.Stop //= [] |
                .hooks.Stop |= (
                  map(select((.hooks // []) | all(.command != $cmd)))
                  + [{matcher: "*", hooks: [{type: "command", command: $cmd}]}]
                )
              ' "$settings" > "$tmp"
            $DRY_RUN_CMD mv "$tmp" "$settings"
          '';
        } else {
          name  = "gsd-stop-hook-codex";
          value = hm.dag.entryAfter [ "gsd-vault-inject-codex" ] ''
            cfgFile="${config.home.homeDirectory}/.codex/config.toml"
            mkdir -p "$(dirname "$cfgFile")"
            touch "$cfgFile"
            tmp=$(mktemp)
            ${pkgs.gnused}/bin/sed '/# BEGIN gsd stop hook/,/# END gsd stop hook/d' "$cfgFile" > "$tmp"
            ${pkgs.gnused}/bin/sed -e :a -e '/^$/{$d;N;ba' -e '}' "$tmp" > "$cfgFile"
            [ -s "$cfgFile" ] && printf '\n' >> "$cfgFile"
            cat >> "$cfgFile" <<EOF
# BEGIN gsd stop hook
[[hooks.Stop]]
command = "${hookCmdPath} codex"
# END gsd stop hook
EOF
          '';
        }
      ) cfg.captureHook.runtimes);
    })
  ]);
}
