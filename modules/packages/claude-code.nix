{ ... }: {
  perSystem = { pkgs, system, ... }: let
    version = "2.1.128";

    src = pkgs.fetchurl {
      url  = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-JKDxDguXKPKwObtWS9H+lq5K7lax4aTcZalN3zrzuUU=";
    };

    # Anthropic ships the real binary as a per-platform optional npm
    # dep. install.cjs hardlinks it over bin/claude.exe (a placeholder
    # stub) at npm-install time. We replicate that here.
    platformSrcs = {
      "x86_64-linux"  = { suffix = "linux-x64";    hash = "sha256-2vbjt5egrwBJiB0fCTxBpvbz+ksSWQF+LvglcoIDf+o="; };
      "aarch64-linux" = { suffix = "linux-arm64";  hash = "sha256-89Xt5PyWd2k0CZb8kcxDseIwFk6I9esQsDJdu+XGIZo="; };
      "x86_64-darwin" = { suffix = "darwin-x64";   hash = "sha256-XMRZexj+GXtmsATnmTLVuBEUg2aDjIUxDLfe9ygaHcw="; };
      "aarch64-darwin"= { suffix = "darwin-arm64"; hash = "sha256-hWjqU9qN5g0o484xo5Ex2vbl4yFUc0oVEtVz+DLYx/U="; };
    };
    plat = platformSrcs.${system} or (throw "claude-code: unsupported system ${system}");

    platformSrc = pkgs.fetchurl {
      url  = "https://registry.npmjs.org/@anthropic-ai/claude-code-${plat.suffix}/-/claude-code-${plat.suffix}-${version}.tgz";
      inherit (plat) hash;
    };

    pkg = pkgs.stdenv.mkDerivation {
      pname = "claude-code";
      inherit version src;

      nativeBuildInputs = with pkgs; [ makeWrapper ]
        ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.autoPatchelfHook;

      buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [
        stdenv.cc.cc.lib
        zlib
      ]);

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

        install -Dm755 ../platform/package/claude $PWD/bin/claude.exe

        mkdir -p $out/lib/node_modules/@anthropic-ai/claude-code
        cp -r ./. $out/lib/node_modules/@anthropic-ai/claude-code/

        mkdir -p $out/bin
        # claude.exe is a Bun single-file executable that picks its
        # embedded entry from argv[0]. Invoking it as "claude" makes
        # Bun fall back to its generic CLI, so force argv[0]=claude.exe.
        makeWrapper \
          $out/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe \
          $out/bin/claude \
          --argv0 claude.exe

        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "Anthropic Claude Code CLI (npm-pinned)";
        homepage    = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
        license     = licenses.unfreeRedistributable;
        platforms   = builtins.attrNames platformSrcs;
        mainProgram = "claude";
      };
    };
  in {
    packages.claude-code = pkg;
  };
}
