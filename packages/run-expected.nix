# run_expected: scope expected command failures so unexpected ones surface loudly.
#
# A source-able function library (writeTextFile — no shebang, not executable).
# Apps `source` it to get:
#
#   run_expected <exit> <stderr-regex> -- <cmd...>
#     -> 0 if <cmd> succeeds
#     -> 1 if <cmd> fails with EXACTLY exit <exit> AND stderr matches <stderr-regex>
#     -> exits 1 (loudly) on any OTHER failure (typo, missing dep, unexpected state)
{
  pkgs,
  inputs,
  system,
  ...
}:
let
  assertHelper = "assert() { [[ \"$1\" ]] || { echo \"FAIL: $2\" >&2; exit 1; }; }";
  self = inputs.self.packages.${system}.run-expected;
in
pkgs.writeTextFile {
  name = "run-expected";
  passthru.tests =
    let
      setup = ''
        source ${self}
        ${assertHelper}
      '';
      teardown = "touch $out";
    in
    {
      expected-failure-returns-one = pkgs.runCommand "expected-failure-returns-one" { } ''
        ${setup}

        fail_boom() { echo "boom" >&2; return 3; }
        run_expected 3 "boom" -- fail_boom || rc=$?
        assert "$rc = 1" "expected failure should return 1"

        ${teardown}
      '';
      shellcheck = pkgs.runCommand "shellcheck" { } ''
        ${pkgs.shellcheck}/bin/shellcheck -x ${self}
        touch $out
      '';
      success-returns-zero = pkgs.runCommand "success-returns-zero" { } ''
        ${setup}

        run_expected 3 "boom" -- true
        assert "$? = 0" "success should return 0"

        ${teardown}
      '';
      unexpected-failure-is-loud = pkgs.runCommand "unexpected-failure-is-loud" { } ''
        ${setup}

        fail_different() { echo "different" >&2; return 3; }
        err="$(mktemp)"
        ( run_expected 3 "boom" -- fail_different 2>"$err" ) || rc=$?
        assert "$rc = 1" "unexpected failure should exit 1 (got $rc)"
        grep -q "UNEXPECTED failure" "$err" \
          || { echo "FAIL: unexpected failure was not loud" >&2; exit 1; }
        rm -f "$err"

        ${teardown}
      '';
    };
  text = ''
    # shellcheck shell=bash
    run_expected() {
      local want_exit="$1" want_regex="$2"
      shift 2
      [[ "$1" == "--" ]] && shift
      local out err rc
      out="$(mktemp)"
      err="$(mktemp)"
      "$@" >"$out" 2>"$err"
      rc=$?
      if [[ $rc -eq 0 ]]; then
        cat "$out"
        rm -f "$out" "$err"
        return 0
      fi
      if [[ $rc -eq "$want_exit" ]] && grep -qE "$want_regex" "$err"; then
        rm -f "$out" "$err"
        return 1
      fi
      echo "UNEXPECTED failure (exit $rc): $*" >&2
      cat "$err" >&2
      rm -f "$out" "$err"
      exit 1
    }
  '';
}
