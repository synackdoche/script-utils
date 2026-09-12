# L_lib: vendored kamilcuk/L_lib (GPL-3.0), pinned at v2.0.4.
#
# A standard derivation of the upstream repo content. The main library is
# `bin/L_lib.sh`; source it with the silent flag so sourcing prints nothing:
#
#   source ${L_lib}/bin/L_lib.sh -s
{
  pkgs,
  inputs,
  pname,
  system,
  ...
}:
let
  self = inputs.self.packages.${system}.L_lib;
  src = pkgs.fetchFromGitHub {
    hash = "sha256-4hZiIBNO0kFzTIBaJszKpgOOtFPYHTokjTIkSDy4UHY=";
    owner = "kamilcuk";
    repo = "L_lib";
    rev = "v${version}";
  };
  version = "2.0.4";
in
pkgs.stdenv.mkDerivation {
  inherit src version;
  inherit pname;
  dontCheckBrokenSymlinks = true;
  dontPatchShebangs = true;
  dontStrip = true;
  dontUnpack = true;
  installPhase = ''
    mkdir -p "$out"
    cp -r "$src"/. "$out"/
  '';
  meta = {
    description = "Labrador Bash library";
    homepage = "https://github.com/kamilcuk/L_lib";
    license = pkgs.lib.licenses.gpl3Only;
    maintainers = [ ];
    platforms = pkgs.lib.platforms.all;
  };
  passthru.tests =
    let
      setup = ''
        source ${self}/bin/L_lib.sh -s
      '';
      teardown = "touch $out";
    in
    {
      kebab-case-flags = pkgs.runCommand "kebab-case-flags" { } ''
        ${setup}

        L_argparse \
          -- --out-dir help="output dir" \
          -- --pin help="pin" \
          -- --force-wipe flag=1 help="wipe" \
          ---- --out-dir ./x --pin 1234 --force-wipe
        [[ "$out_dir" == "./x" ]] || { echo "FAIL: out_dir=$out_dir" >&2; exit 1; }
        [[ "$pin" == "1234" ]] || { echo "FAIL: pin=$pin" >&2; exit 1; }
        [[ "$force_wipe" == "1" ]] || { echo "FAIL: force_wipe=$force_wipe" >&2; exit 1; }

        ${teardown}
      '';
      missing-value-exits-one = pkgs.runCommand "missing-value-exits-one" { } ''
        ${setup}

        ( L_argparse -- --pin help="pin" ---- --pin 2>/dev/null ) || rc=$?
        [[ "$rc" == "1" ]] || { echo "FAIL: expected exit 1, got $rc" >&2; exit 1; }

        ${teardown}
      '';
      shellcheck = pkgs.runCommand "shellcheck" { } ''
        ${pkgs.shellcheck}/bin/shellcheck -x ${self}/bin/L_lib.sh
        touch $out
      '';
    };
}
