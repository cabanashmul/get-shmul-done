{ ... }: {
  perSystem = { pkgs, ... }: let
    version = "1.40.0";
    src = pkgs.fetchurl {
      url  = "https://registry.npmjs.org/get-shit-done-cc/-/get-shit-done-cc-${version}.tgz";
      hash = "sha256-OwtC4nbqtFcjWuqzBVSbA+z8Gql+w4fD0IB5xjhUZI0=";
    };

    # The tarball ships dist/ pre-built but no node_modules. Runtime deps
    # (@anthropic-ai/claude-agent-sdk, ws) live in sdk/package-lock.json.
    # Build the sdk subdir with buildNpmPackage so npm ci runs offline against
    # a Nix-fetched dep store, then assemble the full package layout in $out.
    pkg = pkgs.buildNpmPackage {
      pname = "gsd-cc";
      inherit version src;

      sourceRoot = "package/sdk";
      npmDepsHash = "sha256-PBomToSeI1NiedDQk9l8dtGWK4N8AxP0gcEMfepxcO4=";

      # dist/ is shipped pre-built; don't re-run tsc.
      dontNpmBuild = true;

      nativeBuildInputs = [ pkgs.makeWrapper ];

      installPhase = ''
        runHook preInstall

        ROOT="$out/lib/node_modules/get-shit-done-cc"
        mkdir -p "$ROOT"

        # cwd is package/sdk with node_modules from npm ci — go up to package/
        # and copy the entire tree (sdk/ included) into $out.
        cd ..
        cp -r . "$ROOT/"

        # Resolution from bin/*.js walks up to $ROOT/node_modules; point it at
        # the sdk's installed deps so root-level imports resolve too.
        ln -s sdk/node_modules "$ROOT/node_modules"

        mkdir -p $out/bin
        for bin in get-shit-done-cc gsd-sdk gsd-tools; do
          target=$ROOT/bin/$bin.js
          [[ "$bin" = "get-shit-done-cc" ]] && target=$ROOT/bin/install.js
          [[ "$bin" = "gsd-sdk" || "$bin" = "gsd-tools" ]] && target=$ROOT/bin/gsd-sdk.js
          makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/$bin --add-flags "$target"
        done

        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "GSD — multi-runtime AI dev tool installer";
        homepage    = "https://www.npmjs.com/package/get-shit-done-cc";
        license     = licenses.mit;
        platforms   = platforms.unix;
        mainProgram = "get-shit-done-cc";
      };
    };
  in {
    packages.gsd-cc = pkg;
  };
}
