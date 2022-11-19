{ flake-utils }:

rec {
  # pick the default package from a flake import
  flake-def-pkg = system: p: p.defaultPackage.${system};

  # xs is an attrSet of flake packages by name; `pcks` maps them
  # to their derivations (of their default packages) (returning
  # an attrSet from name to derivation)
  pcks = system: xs:
#    builtins.mapAttrs (pname: p: p.defaultPackage.${system}) xs;
    builtins.mapAttrs (_: flake-def-pkg system) xs;

  hPackage = system: pkgs: name: self: opts:
    let
      haskellPackages = pkgs.haskellPackages;
      haskellLib      = pkgs.haskell.lib;
      # don't unbreak any packages
      default_unbreak = _: {};
      # opts.unbreak, if defined, should be a unary function from an attrSet of
      # haskellpackages to an attrSet of packages that should be unbroken
      unbreak         = opts.unbreak or default_unbreak;
      # (unbreak haskellPackages) is an attrSet of packages to unbreak; e.g.,
      # { "text-format" = haskellPackages.text-format; }
      # thus unbroken does the deed, leaving us with (e.g.,) an attrSet of
      # packages with the unbroken tag removed
      unbroken        = builtins.mapAttrs (_: p: haskellLib.markUnbroken p)
                                          (unbreak haskellPackages);
      d = ((pcks system (opts.deps or {})) // unbroken);
      mapPkg = map (flake-def-pkg system);
    in
      if opts ? callPackage
      then (haskellPackages.callPackage opts.callPackage ({ inherit mapPkg system; } // unbroken))
      else # callCabal2nix uses IFD, which is slow and memory-hungry
           # https://github.com/cdepillabout/cabal2nixWithoutIFD
           # pkgs.lib.trivial.warn "pkg ${name} is using callCabal2nix"
             (haskellPackages.callCabal2nix name self d).overrideAttrs(
               (opts.overrideAttrs or (_: _: {})) pkgs
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

        p = hPackage system nixpkgs packageName self opts;
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
