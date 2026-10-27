{
  description = "omc, the Omega compiler, born from the 408-byte seed of aien-dev/omega-mv (aarch64-linux only)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      commit = "e5b32567a7aff3ce594e3254a622a846a6cd190b";
      omcSha256 = "2c82480596bbdc50cda9626866209ef662d5834f278f839ff4ce0250c495029f";

      omc = pkgs.stdenvNoCC.mkDerivation {
        pname = "omc";
        version = "0.0.0+git.${builtins.substring 0 8 commit}";
        src = pkgs.fetchurl {
          url = "https://github.com/aien-dev/omega-mv/archive/${commit}.tar.gz";
          hash = "sha256-xiG2zv5yjWeholOp2JkUlUBkYNNl3ZHqNWRR6yJUqVw=";
        };
        # The seed chain needs only sh, printf, cat, stat, sed, sha256sum and cmp (all in stdenv).
        dontConfigure = true;
        buildPhase = ''
          runHook preBuild
          sh seed/omega-from-seed.sh
          echo "${omcSha256}  seed/out/omc" | sha256sum -c -
          runHook postBuild
        '';
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          ./seed/out/omc < ${./examples/hello.om} > hello
          chmod +x hello
          test "$(./hello)" = "omega 55"
          runHook postCheck
        '';
        installPhase = ''
          runHook preInstall
          install -Dm755 seed/out/omc $out/bin/omc
          runHook postInstall
        '';
        # omc is a static ELF whose bytes are pinned; strip/patchelf must not touch it.
        dontFixup = true;
        meta = {
          description = "Omega compiler, born from a 408-byte hand-written seed";
          homepage = "https://github.com/aien-dev/omega-mv";
          license = pkgs.lib.licenses.asl20;
          platforms = [ "aarch64-linux" ];
          mainProgram = "omc";
        };
      };
    in
    {
      packages.${system} = {
        inherit omc;
        default = omc;
      };
      apps.${system} = rec {
        omc = { type = "app"; program = "${self.packages.${system}.omc}/bin/omc"; };
        default = omc;
      };
      checks.${system}.omc-hash = pkgs.runCommand "omc-hash" { } ''
        echo "${omcSha256}  ${omc}/bin/omc" | sha256sum -c - > $out
      '';
    };
}
