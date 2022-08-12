{ pkgs }: with pkgs; let

  ghcCharged =  haskellPackages.ghcWithPackages (p: with p; [
                  haskell-language-server
                  ghcid
                ]);
  ghcid-bin = haskellPackages.ghcid.bin;

  ghcid-bin-with-openblas = let
    ghcid = "${ghcid-bin}/bin/ghcid";
    out = "$out/bin/ghcid";
  in runCommand "ghcid" { buildInputs = [ makeWrapper ]; } ''
    makeWrapper ${ghcid} ${out} --add-flags \
      "--command='cabal repl lib:cuda'"
  '';

in
  haskellPackages.cuda.env.overrideAttrs (old: {
    nativeBuildInputs =  old.nativeBuildInputs ++
                  [ ghcCharged
                    ghcid-bin-with-openblas
                    cabal-install
                    openblasCompat
                    cudatoolkit
                  ];

  })
# }
