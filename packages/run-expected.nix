# run_expected: assert a command's outcome matches an expected signature.
#
# A source-able function library (writeTextFile — no shebang, not executable).
# Apps `source` it to get:
#
#   run_expected <exit> <output-regex> -- <cmd...>
#     -> 0 if <cmd> exits <exit> AND its combined stdout+stderr matches
#        <output-regex>
#     -> exits 1 (loudly) on any OTHER outcome: a different exit code, output
#        that doesn't match, or success when a failure was expected
#     Use <exit> 0 to assert a successful command whose output matches the regex.
#
#   run_expected_any <sigs-assoc> -- <cmd...>
#     -> 0 if <cmd> matches ANY signature in <sigs-assoc> (an associative
#        array mapping exit code -> output-regex); compose success-or-error,
#        or any of several errors
#     -> exits 1 (loudly) on any OTHER outcome
#     The signature map is a named associative array, so it is reusable and
#     self-documenting:
#       declare -A sigs=([0]=".*" [3]="boom")
#       run_expected_any sigs -- cmd
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
      any-matches-empty-output = pkgs.runCommand "any-matches-empty-output" { } ''
        ${setup}

        declare -A sigs=([0]=".*")
        run_expected_any sigs -- true
        rc=$?
        assert "$rc = 0" ".* should match empty output (got $rc)"

        ${teardown}
      '';
      any-of-multiple = pkgs.runCommand "any-of-multiple" { } ''
        ${setup}

        fail_bang() { echo "bang" >&2; return 5; }
        declare -A sigs=([3]="boom" [5]="bang")
        run_expected_any sigs -- fail_bang
        rc=$?
        assert "$rc = 0" "failure matching any signature should return 0"

        ${teardown}
      '';
      expected-outcome-returns-zero = pkgs.runCommand "expected-outcome-returns-zero" { } ''
        ${setup}

        fail_boom() { echo "boom" >&2; return 3; }
        run_expected 3 "boom" -- fail_boom
        rc=$?
        assert "$rc = 0" "expected failure should return 0"

        ${teardown}
      '';
      matches-stdout = pkgs.runCommand "matches-stdout" { } ''
        ${setup}

        say_stdout() { echo "hello" >&1; return 0; }
        run_expected 0 "hello" -- say_stdout
        rc=$?
        assert "$rc = 0" "regex should match stdout (got $rc)"

        ${teardown}
      '';
      shellcheck = pkgs.runCommand "shellcheck" { } ''
        ${pkgs.shellcheck}/bin/shellcheck -x ${self}
        touch $out
      '';
      success-or-error = pkgs.runCommand "success-or-error" { } ''
        ${setup}

        say_success() { echo "success" >&2; return 0; }
        declare -A sigs=([0]="success" [3]="boom")
        run_expected_any sigs -- say_success
        rc=$?
        assert "$rc = 0" "success should be accepted (got $rc)"

        fail_boom() { echo "boom" >&2; return 3; }
        run_expected_any sigs -- fail_boom
        rc=$?
        assert "$rc = 0" "expected error should be accepted (got $rc)"

        ${teardown}
      '';
      success-when-failure-expected-is-loud =
        pkgs.runCommand "success-when-failure-expected-is-loud" { }
          ''
            ${setup}

            err="$(mktemp)"
            ( run_expected 3 "boom" -- true 2>"$err" ) || rc=$?
            assert "$rc = 1" "success under an expected-failure signature should exit 1 (got $rc)"
            grep -q "UNEXPECTED" "$err" \
              || { echo "FAIL: unexpected outcome was not loud" >&2; exit 1; }
            rm -f "$err"

            ${teardown}
          '';
      success-with-output-check = pkgs.runCommand "success-with-output-check" { } ''
        ${setup}

        say_success() { echo "success" >&2; return 0; }
        run_expected 0 "success" -- say_success
        rc=$?
        assert "$rc = 0" "success with matching output should return 0"

        ${teardown}
      '';
      unexpected-failure-is-loud = pkgs.runCommand "unexpected-failure-is-loud" { } ''
        ${setup}

        fail_different() { echo "different" >&2; return 3; }
        err="$(mktemp)"
        ( run_expected 3 "boom" -- fail_different 2>"$err" ) || rc=$?
        assert "$rc = 1" "unexpected failure should exit 1 (got $rc)"
        grep -q "UNEXPECTED" "$err" \
          || { echo "FAIL: unexpected failure was not loud" >&2; exit 1; }
        rm -f "$err"

        ${teardown}
      '';
    };
  text = ''
    # shellcheck shell=bash
    # _run_match: run <cmd...>; 0 if the outcome matches any (exit, output-regex)
    # pair in the map named by $1, else 1. Replays combined output on a match.
    _run_match() {
      local -n sigmap="$1"
      shift
      [[ "$1" == "--" ]] && shift
      local out rc
      out="$(mktemp)"
      "$@" >"$out" 2>&1
      rc=$?
      local k
      for k in "''${!sigmap[@]}"; do
        if [[ $rc -eq "$k" ]] && grep -qE "''${sigmap[$k]}" <<< "$(cat "$out")"; then
          cat "$out"
          rm -f "$out"
          return 0
        fi
      done
      echo "UNEXPECTED outcome (exit $rc): $*" >&2
      cat "$out" >&2
      rm -f "$out"
      return 1
    }

    run_expected() {
      # shellcheck disable=SC2034 # sigs is used via the sigmap nameref
      local -A sigs=(["$1"]="$2")
      _run_match sigs "''${@:3}" || exit 1
    }

    run_expected_any() {
      _run_match "$1" "''${@:2}" || exit 1
    }
  '';
}
