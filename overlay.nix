final: prev: with final; {

  haskellPackages = prev.haskell.packages.ghc922.override (old: {
    overrides = lib.composeManyExtensions [
                  (old.overrides or (_: _: {}))
                  (hfinal: hprev: with haskell.lib; rec {
                    cuda =
                      let
                        pkg = hfinal.callCabal2nix "cuda"  ./. { };
                      in
                        overrideCabal pkg (drv: {
                          extraLibraries = (drv.extraLibraries or []) ++ [pkgs.linuxPackages.nvidia_x11];
                          configureFlags = (drv.configureFlags or []) ++ [
                            "--extra-lib-dirs=${pkgs.cudatoolkit.lib}/lib"
                            "--extra-include-dirs=${pkgs.cudatoolkit}/include"
                          ];
                          preConfigure = ''
                            export CUDA_PATH=${pkgs.cudatoolkit}
                        #   '';
                        });
                  })
                ];
  });

}
