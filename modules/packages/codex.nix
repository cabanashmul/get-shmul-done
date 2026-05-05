{ ... }: {
  perSystem = { pkgs, system, ... }: let
    version = "0.128.0";

    src = pkgs.fetchurl {
      url  = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
      hash = "sha256-SW/Tg3aTfqLDORf0KMVNWYRtbc5Qbptpn8FBO+4h+fg=";
    };

    # codex.js spawns a per-platform native binary it expects to find at
    # vendor/${targetTriple}/codex/codex (static-pie musl ELF, no
    # patchelf needed) and ./path/rg.
    platformSrcs = {
      "x86_64-linux"  = { suffix = "linux-x64";    triple = "x86_64-unknown-linux-musl";  hash = "sha256-IRYLT2ry9j54ec0iwkwVp4loMybwPL8czumlZtODU3g="; };
      "aarch64-linux" = { suffix = "linux-arm64";  triple = "aarch64-unknown-linux-musl"; hash = "sha256-o4f6aUukTAm7M31YyrcgzgkvRjHubZKCsSgIcqlXZa8="; };
      "x86_64-darwin" = { suffix = "darwin-x64";   triple = "x86_64-apple-darwin";        hash = "sha256-H0/6PHDCQ8KZPe22djX2qYwT0/K4alyqRF73YlMvwh8="; };
      "aarch64-darwin"= { suffix = "darwin-arm64"; triple = "aarch64-apple-darwin";       hash = "sha256-JUmdlXrhjTF80TASdQ5oGmCh185F9XfG8H5T03QZnZs="; };
    };
    plat = platformSrcs.${system} or (throw "codex: unsupported system ${system}");

    platformSrc = pkgs.fetchurl {
      url  = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-${plat.suffix}.tgz";
      inherit (plat) hash;
    };

    pkg = pkgs.stdenv.mkDerivation {
      pname = "codex";
      inherit version src;

      nativeBuildInputs = [ pkgs.makeWrapper ];

      unpackPhase = ''
        runHook preUnpack
        tar -xzf $src
        mkdir platform
        tar -xzf ${platformSrc} -C platform
        runHook postUnpack
      '';

      sourceRoot = "package";

      installPhase = ''
        runHook preInstall

        cp -r ../platform/package/vendor $PWD/vendor
        chmod -R u+w $PWD/vendor

        mkdir -p $out/lib/node_modules/@openai/codex
        cp -r ./. $out/lib/node_modules/@openai/codex/

        mkdir -p $out/bin
        makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/codex \
          --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"

        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "OpenAI Codex CLI (npm-pinned)";
        homepage    = "https://www.npmjs.com/package/@openai/codex";
        license     = licenses.asl20;
        platforms   = builtins.attrNames platformSrcs;
        mainProgram = "codex";
      };
    };
  in {
    packages.codex = pkg;
  };
}
