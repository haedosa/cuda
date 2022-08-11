final: prev: with final; {

  haskellPackages = prev.haskell.packages.ghc922.override (old: {
    overrides = lib.composeManyExtensions [
                  (old.overrides or (_: _: {}))
                  (hfinal: hprev: {
                    cuda = hfinal.callCabal2nix "cuda"  ./. { };
                  })
                ];
  });

}
