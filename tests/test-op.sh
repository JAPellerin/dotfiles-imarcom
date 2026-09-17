#!/usr/bin/env bash
# tests/test-op.sh — lib/op.sh sans session 1Password (et sans `op` si absent).
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"

if op_session_active; then
  printf 'Une session 1Password est active dans ce shell : les cas « sans session » sont sautés.\n'
  out=$(op_read "op://x" 2>&1) || true
  assert_contains "op_read exige une référence op:// bien formée" "$out" "référence invalide"
  test_done
  exit
fi

printf '%s\n' "== op_session_active =="
assert_fail "faux sans session (ou sans op installé)" op_session_active

printf '%s\n' "== op_read =="
assert_fail "échoue sans session" op_read op://Perso/GitHub/token
out=$(op_read op://Perso/GitHub/token 2>&1 >/dev/null)
assert_contains "message : lancer setup.sh 1password" "$out" "setup.sh 1password"
assert_eq "rien sur stdout sans session" "" "$(op_read op://Perso/GitHub/token 2>/dev/null)"
assert_fail "référence sans op:// refusée" op_read Perso/GitHub/token
assert_fail "sans argument refusé" op_read
assert_not_contains "la référence n'est pas journalisée comme secret (seulement l'erreur)" "$(cat "$LOG_FILE")" "op read"

# Doublure : `op` présent mais sans session → op whoami échoue.
printf '%s\n' "== avec une doublure de op sans session =="
mkdir -p "$TEST_TMP/bin"
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  whoami) echo "[ERROR] no session" >&2; exit 1 ;;
  read)   echo "ne-doit-pas-etre-lu" ;;
esac
FAKE
chmod +x "$TEST_TMP/bin/op"
PATH="$TEST_TMP/bin:$PATH"
assert_fail "op_session_active faux si op whoami échoue" op_session_active
assert_eq "op_read ne lit rien quand whoami échoue" "" "$(op_read op://Perso/GitHub/token 2>/dev/null)"

# Doublure : session active → op read est appelé et la valeur revient sur stdout seulement.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  whoami) exit 0 ;;
  read)   printf 'valeur-secrete' ;;
esac
FAKE
assert_ok "op_session_active vrai si op whoami réussit" op_session_active
assert_eq "op_read renvoie le secret sur stdout" "valeur-secrete" "$(op_read op://Perso/GitHub/token 2>/dev/null)"
assert_not_contains "le secret n'apparaît pas dans le journal" "$(cat "$LOG_FILE")" "valeur-secrete"

test_done
