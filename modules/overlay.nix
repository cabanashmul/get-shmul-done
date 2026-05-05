{ self, ... }: {
  flake.overlays.default = final: prev: {
    inherit (self.packages.${final.stdenv.hostPlatform.system})
      claude-code codex copilot gsd-cc;
  };
}
