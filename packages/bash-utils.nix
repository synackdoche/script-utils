# bash-utils: generic bash helpers (coreutils only, no domain-specific tools).
#
# A source-able function library (writeTextFile — no shebang, not executable).
# Apps `source` it to get:
#
#   die <msg>...            -> print to stderr and exit 1
#   warn <msg>...           -> print to stderr (no exit)
#   require_cmd <cmd>       -> exit 1 loudly if <cmd> is not on PATH
#   is_blank <str>          -> 0 if <str> is empty or only whitespace
#   join <sep> <a> <b>...   -> join args with <sep>
#   trim <str>              -> echo <str> with leading/trailing whitespace removed
{
  pkgs,
  inputs,
  system,
  ...
}:
let
  assertHelper = "assert() { [[ \"$1\" ]] || { echo \"FAIL: $2\" >&2; exit 1; }; }";
  self = inputs.self.packages.${system}.bash-utils;
in
pkgs.writeTextFile {
  name = "bash-utils";
  passthru.tests =
    let
      setup = ''
        source ${self}
        ${assertHelper}
      '';
      teardown = "touch $out";
    in
    {
      die-exits-one = pkgs.runCommand "die-exits-one" { } ''
        ${setup}

        ( die "boom" 2>/dev/null ) || rc=$?
        assert "$rc = 1" "die should exit 1 (got $rc)"

        ${teardown}
      '';
      is-blank-empty = pkgs.runCommand "is-blank-empty" { } ''
        ${setup}

        is_blank ""
        assert "$? = 0" "is_blank should be true for empty string"

        ${teardown}
      '';
      is-blank-nonblank = pkgs.runCommand "is-blank-nonblank" { } ''
        ${setup}

        is_blank "x" || rc=$?
        assert "$rc != 0" "is_blank should be false for non-blank (got $rc)"

        ${teardown}
      '';
      is-blank-whitespace = pkgs.runCommand "is-blank-whitespace" { } ''
        ${setup}

        is_blank "   "
        assert "$? = 0" "is_blank should be true for whitespace"

        ${teardown}
      '';
      join-args = pkgs.runCommand "join-args" { } ''
        ${setup}

        assert "$(join , a b c) = a,b,c" "join should join args with separator"

        ${teardown}
      '';
      require-cmd-found = pkgs.runCommand "require-cmd-found" { } ''
        ${setup}

        require_cmd "true"
        assert "$? = 0" "require_cmd should succeed for an existing command"

        ${teardown}
      '';
      require-cmd-missing = pkgs.runCommand "require-cmd-missing" { } ''
        ${setup}

        ( require_cmd "definitely-not-a-cmd-xyz" 2>/dev/null ) || rc=$?
        assert "$rc = 1" "require_cmd should exit 1 for a missing command (got $rc)"

        ${teardown}
      '';
      shellcheck = pkgs.runCommand "shellcheck" { } ''
        ${pkgs.shellcheck}/bin/shellcheck -x ${self}
        touch $out
      '';
      trim-whitespace = pkgs.runCommand "trim-whitespace" { } ''
        ${setup}

        assert "$(trim '  hi  ') = hi" "trim should strip leading/trailing whitespace"

        ${teardown}
      '';
      warn-no-exit = pkgs.runCommand "warn-no-exit" { } ''
        ${setup}

        warn "hi" 2>/dev/null
        assert "$? = 0" "warn should not exit"

        ${teardown}
      '';
    };
  text = ''
    # shellcheck shell=bash
    die() {
      echo "ERROR: $*" >&2
      exit 1
    }

    warn() {
      echo "WARNING: $*" >&2
    }

    require_cmd() {
      local cmd="$1"
      if ! command -v "$cmd" >/dev/null 2>&1; then
        die "required command not found: $cmd"
      fi
    }

    is_blank() {
      [[ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ]]
    }

    join() {
      local sep="$1"
      shift
      local out="" first=1
      for item in "$@"; do
        if [[ $first -eq 1 ]]; then
          out="$item"
          first=0
        else
          out="$out$sep$item"
        fi
      done
      printf '%s' "$out"
    }

    trim() {
      printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
    }
  '';
}
