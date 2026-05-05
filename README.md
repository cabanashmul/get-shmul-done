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

    vault = {
      enable = true;

      # Optional: prepended above the vault block in every provider's
      # instructions file. Use it for personal policy that should reach
      # claude-code, codex, and copilot uniformly.
      injectInstructions.preamble = ''
        # Personal policy
        ...
      '';
    };
  };
}
```

## GSD

[Get Shit Done](https://github.com/tachesimazzoca/get-shit-done-cc) (GSD) is a
meta-prompting / spec-driven workflow that ships as `get-shit-done-cc` on npm
and installs into each AI runtime's config dir (skills, agents, hooks,
templates).

### What this flake does with GSD

- **Pins the npm package** (`gsd-cc` in `modules/packages/gsd.nix`) by version +
  sha256, same as the runtimes.
- **Exposes the bins on PATH** — `home.packages` includes the `gsd-cc`
  derivation, which exports `get-shit-done-cc`, `gsd-sdk`, and `gsd-tools`.
  No `~/.local/bin` shim needed.
- **Runs the installer per provider on activation**, with stdin detached and
  `--global --yes` to keep it non-interactive:

  ```
  get-shit-done-cc --claude  --global --yes < /dev/null
  get-shit-done-cc --codex   --global --yes < /dev/null
  get-shit-done-cc --copilot --global --yes < /dev/null
  ```

  The installer is idempotent — re-running it on every switch is cheap and
  safe.

### Personal-policy preamble

`programs.gsd.vault.injectInstructions.preamble` is the canonical place for
rules that should apply to every runtime: commit discipline, package policy,
session-start ritual, note-writing triggers, etc. The preamble is prepended
above the vault section inside the bracketed gsd block, so the same content
lands in `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and (appended after
GSD's own block) `~/.copilot/copilot-instructions.md`.

GSD itself owns the workflow scaffolding — advisor / specialist / auditor
flow, agent roster, planning loop. Don't duplicate any of that in the
preamble; keep it for things GSD does *not* cover.

### Updating GSD

`get-shit-done-cc` releases frequently. The weekly `.github/workflows/update.yml`
cron checks npm and opens a PR bumping `version` + `hash` in
`modules/packages/gsd.nix`. Review and merge; the lock bump in the consumer
flake (`nix flake update get-shmul-done`) picks up the new version on the next
`home-manager switch`.

To force-update by hand:

```bash
cd get-shmul-done
$EDITOR modules/packages/gsd.nix    # bump version, set hash to pkgs.lib.fakeHash
nix build .#gsd-cc                  # fails, prints real hash
# paste hash back, rebuild
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
