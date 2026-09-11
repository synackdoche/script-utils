{ pkgs, ... }:
pkgs.runCommand "formatting" { } ''
  ${pkgs.lib.getExe pkgs.nixfmt-tree} --fail-on-change --no-cache ${./.}
  touch $out
''
