#!/usr/bin/env bash
# tests/lib.sh — mini-harnais d'assertions pour les tests Bash du socle (D11).
#
# Usage dans un test :
#   source "$(dirname "$0")/lib.sh"      # charge lib/core.sh avec un journal temporaire
#   assert_ok "description" commande...
#   test_done                            # résumé + code de sortie
#
# Les tests ne posent pas `set -e` : chaque assertion gère son propre échec.
set -uo pipefail

TESTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd -- "$TESTS_DIR/.." && pwd)
TEST_TMP=$(mktemp -d -t dotfiles-test.XXXXXX)
# shellcheck disable=SC2034  # utilisé par les tests qui chargent ce fichier
FIXTURES_DIR="$TESTS_DIR/fixtures"

# Journal et état isolés dans le dossier temporaire : rien n'est écrit sous ~/.local.
DOTFILES_STATE_DIR="$TEST_TMP/state"
LOG_FILE="$DOTFILES_STATE_DIR/setup-test.log"
export DOTFILES_DIR DOTFILES_STATE_DIR LOG_FILE

# shellcheck source=../lib/core.sh
source "$DOTFILES_DIR/lib/core.sh"
add_cleanup "rm -rf '$TEST_TMP'"

# fake_sudo : place un faux `sudo` en tête du PATH (exécute la commande telle
# quelle, accepte -v et -n) pour tester le runner sans droits ni mot de passe.
fake_sudo() {
  mkdir -p "$TEST_TMP/bin"
  cat >"$TEST_TMP/bin/sudo" <<'FAKE'
#!/usr/bin/env bash
[[ ${1:-} == -v ]] && exit 0
[[ ${1:-} == -n ]] && shift
exec "$@"
FAKE
  chmod +x "$TEST_TMP/bin/sudo"
  export PATH="$TEST_TMP/bin:$PATH"
}

_TESTS_RUN=0
_TESTS_FAILED=0

_pass() { _TESTS_RUN=$((_TESTS_RUN + 1)); printf '  %s✔%s %s\n' "$_C_GREEN" "$_C_RESET" "$1"; }
_fail() {
  _TESTS_RUN=$((_TESTS_RUN + 1)); _TESTS_FAILED=$((_TESTS_FAILED + 1))
  printf '  %s✖%s %s\n' "$_C_RED" "$_C_RESET" "$1"
  shift
  local line
  for line in "$@"; do printf '      %s\n' "$line"; done
}

# assert_ok <description> <commande...> : la commande doit réussir.
assert_ok() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then _pass "$desc"; else _fail "$desc" "commande : $*" "attendu : code 0, obtenu : $?"; fi
}

# assert_fail <description> <commande...> : la commande doit échouer.
assert_fail() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then _fail "$desc" "commande : $*" "attendu : code non nul, obtenu : 0"; else _pass "$desc"; fi
}

# assert_rc <description> <code attendu> <commande...>
assert_rc() {
  local desc=$1 expected=$2 rc=0; shift 2
  "$@" >/dev/null 2>&1 || rc=$?
  if [[ $rc -eq $expected ]]; then _pass "$desc"; else _fail "$desc" "commande : $*" "attendu : code $expected, obtenu : $rc"; fi
}

# assert_eq <description> <attendu> <obtenu>
assert_eq() {
  local desc=$1 expected=$2 actual=$3
  if [[ $expected == "$actual" ]]; then _pass "$desc"; else _fail "$desc" "attendu : $expected" "obtenu  : $actual"; fi
}

# assert_contains <description> <texte> <fragment>
assert_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack == *"$needle"* ]]; then _pass "$desc"; else _fail "$desc" "fragment absent : $needle" "texte : ${haystack:0:300}"; fi
}

# assert_not_contains <description> <texte> <fragment>
assert_not_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack != *"$needle"* ]]; then _pass "$desc"; else _fail "$desc" "fragment présent alors qu'il ne devrait pas : $needle"; fi
}

# assert_file <description> <chemin> : le fichier doit exister.
assert_file() {
  local desc=$1 path=$2
  if [[ -f $path ]]; then _pass "$desc"; else _fail "$desc" "fichier absent : $path"; fi
}

# test_done : résumé et code de sortie (1 si au moins un échec).
test_done() {
  printf '\n%s : %d assertion(s), %d échec(s)\n' "$(basename -- "$0")" "$_TESTS_RUN" "$_TESTS_FAILED"
  [[ $_TESTS_FAILED -eq 0 ]]
}
