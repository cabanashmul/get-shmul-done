{ ... }: {
  perSystem = { pkgs, ... }: let
    version = "1.40.0";
    src = pkgs.fetchurl {
      url  = "https://registry.npmjs.org/get-shit-done-cc/-/get-shit-done-cc-${version}.tgz";
      hash = "sha256-OwtC4nbqtFcjWuqzBVSbA+z8Gql+w4fD0IB5xjhUZI0=";
    };
    pkg = pkgs.stdenv.mkDerivation {
      pname = "gsd-cc";
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

        mkdir -p $out/lib/node_modules/get-shit-done-cc
        cp -r ./. $out/lib/node_modules/get-shit-done-cc/

        mkdir -p $out/bin
        for bin in get-shit-done-cc gsd-sdk gsd-tools; do
          target=$out/lib/node_modules/get-shit-done-cc/bin/$bin.js
          [[ "$bin" = "get-shit-done-cc" ]] && target=$out/lib/node_modules/get-shit-done-cc/bin/install.js
          [[ "$bin" = "gsd-sdk" || "$bin" = "gsd-tools" ]] && target=$out/lib/node_modules/get-shit-done-cc/bin/gsd-sdk.js
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
