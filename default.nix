{ flake-utils }:

rec {
  pcks = system: xs:
    builtins.mapAttrs (pname: p: p.defaultPackage.${system}) xs;

  hPackage = system: pkgs: name: self: opts:
    let
      haskellPackages = pkgs.haskellPackages;
      haskellLib      = pkgs.haskell.lib;
      default_unbreak = _: {};
      unbreak         = opts.unbreak or default_unbreak;
      unbroken        = builtins.mapAttrs (_: p: haskellLib.markUnbroken p)
                                          (unbreak haskellPackages);
      d = (pcks system (opts.deps or {})) // unbroken;
    in
      (haskellPackages.callCabal2nix name self d).overrideAttrs(
        opts.overrideAttrs or {}
      );

  hOutputs = self: nixpkgs_: packageName: opts:
    flake-utils.lib.eachDefaultSystem (system:
      let
        trace2    = nixpkgs_.lib.debug.traceSeqN 2;
        chooseGHC = _final: prev:
          let
            ghcNames  = with builtins; filter (x: "ghc" == substring 0 3 x)
                                              (attrNames prev.haskell.packages);
            traceGHCs = trace2 { "available haskell packages" = ghcNames; };
            pickGHC   = opts.ghc or (p: p.ghcHEAD); ## no opts.ghc =>choose HEAD
          in
            {
              ## uncomment this to see the GHCs available
              haskellPackages = /* traceGHCs */ pickGHC prev.haskell.packages;
            };
        nixpkgs = import nixpkgs_ { system = system;
                                    overlays = [ chooseGHC ];
                                  };

        haskellPackages =
          let
            ghcDeriv =  nixpkgs.haskellPackages.ghc;
            traceGHC = trace2  { "using ghc" = builtins.toString ghcDeriv; };
          in
            ## uncomment this to see the GHC in use
            /* traceGHC */ nixpkgs.haskellPackages;

        p = hPackage system nixpkgs "base0t" self opts;
      in
        {
          packages.${packageName} = p;
          defaultPackage          = p;

          devShell =
            haskellPackages.shellFor {
              ## This brings in all the dependencies of p, so the shell is
              ## useful
              packages = pkgs: [ p ];
              buildInputs =
                with haskellPackages;
                [
                  haskellPackages.haskell-language-server ## you must build it
                                                          ## with your ghc to
                                                          ## work
                  ghcid
                  cabal-install
                ];
              ## This implicitly includes the target package itself; thus, with
              ## this, you cannot enter a `nix develop` shell unless the target
              ## itself builds - which is often when you most need to get into
              ## the shell.
              # inputsFrom = builtins.attrValues self.packages.${system}; # [p];
            };
        }
    );

}
