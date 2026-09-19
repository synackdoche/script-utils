{
  pkgs,
  flake,
}:
let
  formatter = treefmtEval.config.build.wrapper;
  treefmtEval = flake.inputs.treefmt-nix.lib.evalModule pkgs {
    imports = [ flake.inputs.pedantix.treefmtModules.default ];
    programs = {
      deadnix.enable = true;
      flake-edit.enable = true;
      pedantix.enable = true;
      statix.enable = true;
    };
    projectRootFile = "flake.nix";
  };
in
formatter
