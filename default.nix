{ flake-utils }:

rec {
  pcks = system: xs:
    builtins.mapAttrs (pname: p: p.defaultPackage.${system}) xs;

  hPackage = system: pkgs: name: self: deps:
    let
      haskellPackages = pkgs.legacyPackages.${system}.haskellPackages;
    in
      haskellPackages.callCabal2nix name self (pcks system deps);


  hOutputs = self: nixpkgs: packageName: deps:
        flake-utils.lib.eachDefaultSystem (system:
      let
        haskellPackages = nixpkgs.legacyPackages.${system}.haskellPackages;

        p = hPackage system nixpkgs "base0t" self deps;
      in
    {
      packages.${packageName} = p;
      defaultPackage          = p;

      devShell = haskellPackages.shellFor {
        packages = pkgs: [ self.packages.${system}.${packageName}]; # [ p ]
        buildInputs =
          with haskellPackages;
          [
            haskellPackages.haskell-language-server # you must build it with
                                                    # your ghc to work
            ghcid
            cabal-install
          ];
        inputsFrom = builtins.attrValues self.packages.${system}; # [ p ];
      };
    }
    );

}
