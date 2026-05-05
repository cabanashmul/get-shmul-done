{
  description = "get-shmul-done — npm-pinned AI runtimes (claude-code, codex, copilot, gsd) + GSD installer + shmulistan vault integration";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      imports = (inputs.import-tree ./modules).imports;
    };
}
