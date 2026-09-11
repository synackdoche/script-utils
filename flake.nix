{
  description = "SYNACKDOCHE script-utils — reusable, sourcable bash utilities";

  inputs = {
    blueprint = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/blueprint";
    };
    git-hooks.url = "github:cachix/git-hooks.nix";
    nixpkgs.url = "github:synackdoche/nixpkgs/nixos-26.05";
    pedantix.url = "github:swarsel/pedantix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      systems = [ "x86_64-linux" ];
    };
}
