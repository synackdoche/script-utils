{
  pkgs,
  flake,
}:
let
  check = treefmtEval.config.build.wrapper;
  formatter = treefmtEval.config.build.wrapper;
  treefmtEval = flake.inputs.treefmt-nix.lib.evalModule pkgs {
    imports = [ flake.inputs.pedantix.treefmtModules.default ];
    programs.deadnix.enable = true;
    programs.pedantix.enable = true;
    projectRootFile = "flake.nix";
  };
in
formatter
// {
  passthru = formatter.passthru // {
    check = check;
  };
}
