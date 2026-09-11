{ inputs, ... }: {
  treefmtEval =
    pkgs:
    inputs.treefmt-nix.lib.evalModule pkgs {
      imports = [ inputs.pedantix.treefmtModules.default ];
      programs.deadnix.enable = true;
      programs.pedantix.enable = true;
      projectRootFile = "flake.nix";
    };
}
