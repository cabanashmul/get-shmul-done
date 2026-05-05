{ ... }: {
  perSystem = { pkgs, ... }: let
    version = "1.0.40";
    src = pkgs.fetchurl {
      url  = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
      hash = "sha256-y+fFSkiTI5QkdUgAvsvKBXjinCQ5zIWUriDOd/KJeR8=";
    };
    # The npm-loader.js first tries to spawn the platform-specific compiled
    # binary (@github/copilot-${platform}-${arch}, an optionalDependency).
    # If that import resolution fails, it falls back to ./index.js (pure
    # JS, requires Node ≥24). Skipping optional deps forces the JS path
    # and avoids patchelf'ing prebuilt binaries.
    pkg = pkgs.stdenv.mkDerivation {
      pname = "copilot";
      inherit version src;

      nativeBuildInputs = [ pkgs.makeWrapper ];

      unpackPhase = ''
        runHook preUnpack
        tar -xzf $src
        runHook postUnpack
      '';

      sourceRoot = "package";

      installPhase = ''
        runHook preInstall

        mkdir -p $out/lib/node_modules/@github/copilot
        cp -r ./. $out/lib/node_modules/@github/copilot/

        mkdir -p $out/bin
        makeWrapper ${pkgs.nodejs_24}/bin/node $out/bin/copilot \
          --add-flags "$out/lib/node_modules/@github/copilot/npm-loader.js"

        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "GitHub Copilot CLI (npm-pinned, JS fallback path)";
        homepage    = "https://www.npmjs.com/package/@github/copilot";
        license     = licenses.unfreeRedistributable;
        platforms   = platforms.unix;
        mainProgram = "copilot";
      };
    };
  in {
    packages.copilot = pkg;
  };
}
