# get-shmul-done

Personal Home Manager module + npm-pinned AI runtime packages.

Replaces `shmulcode`, `shmulex`, and `shmulistan` (the HM-module side) with a
single private flake.

## What it does

1. Packages four npm-published AI runtimes as Nix derivations, pinned by
   version + sha256:
   - `claude-code` (`@anthropic-ai/claude-code`)
   - `codex` (`@openai/codex`)
   - `copilot` (`@github/copilot`)
   - `gsd-cc` (`get-shit-done-cc`)
2. Installs the runtime binaries and runs GSD per enabled provider via the
   `programs.gsd.*` Home Manager options.
3. Integrates the [shmulistan](https://github.com/shmul95/shmulistan) vault
   for bidirectional memory: vault path is injected into each runtime's
   instructions file (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
   `~/.copilot/copilot-instructions.md`); a Stop hook auto-captures session
   transcripts into `${vault}/00_Inbox/` for `claude-code` and `codex`.

## Usage

In a consumer flake:

```nix
{
  inputs.get-shmul-done.url = "git+ssh://git@github.com/shmul95/get-shmul-done";
  inputs.get-shmul-done.inputs.nixpkgs.follows = "nixpkgs";

  # ... in your home configuration:
  imports = [ inputs.get-shmul-done.homeManagerModules.default ];

  programs.gsd = {
    enable    = true;
    providers = [ "claude-code" "codex" "copilot" ];
    minimal   = false;

    vault.enable = true;
  };
}
```

## Bumping a package version

When the auto-update workflow opens a PR, or when bumping by hand:

1. Edit `version` in `modules/packages/<runtime>.nix`.
2. Set both `hash` (tarball) and `npmDepsHash` (lockfile deps) to
   `pkgs.lib.fakeHash`.
3. Run `nix build .#<runtime>` — it fails twice and prints the real hashes.
4. Paste the real hashes back into the file. Build again — passes.

## Layout

```
modules/
  packages/
    claude-code.nix    # @anthropic-ai/claude-code
    codex.nix          # @openai/codex
    copilot.nix        # @github/copilot
    gsd.nix            # get-shit-done-cc
  gsd.nix              # programs.gsd.* options + activation
  vault.nix            # programs.gsd.vault.* options + activation
  overlay.nix          # flake.overlays.default
stop-hook/
  capture-to-vault.sh  # Stop-hook body
.github/workflows/
  check.yml            # nix flake check on push
  update.yml           # weekly cron, bumps the four npm packages
```

## License

MIT. Personal use only — not intended for distribution.
