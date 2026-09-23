#!/usr/bin/env bash
# tests/test-groups.sh — lib/groups.sh avec des doublures (getent et id lus dans
# des fichiers, run_sudo qui journalise et simule groupadd et usermod) : aucun
# groupe réel touché, aucun sudo.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
# shellcheck source=../lib/groups.sh
source "$DOTFILES_DIR/lib/groups.sh"

mkdir -p "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP"
export USER=u
GROUPS_DB="$TEST_TMP/groups"; : >"$GROUPS_DB"       # lignes « nom:x:gid:membres »
SESSION="$TEST_TMP/session-groups"; printf 'u sudo' >"$SESSION"
CALLS="$TEST_TMP/calls"; : >"$CALLS"

cat >"$TEST_TMP/bin/getent" <<'FAKE'
#!/usr/bin/env bash
[ "$1" = group ] || exit 2
grep "^$2:" "$FAKE_DIR/groups" || exit 2
FAKE
cat >"$TEST_TMP/bin/id" <<'FAKE'
#!/usr/bin/env bash
case ${1:-} in
  -nG) cat "$FAKE_DIR/session-groups"; printf '\n' ;;
  -un) printf 'u\n' ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublure : journalise ; groupadd ajoute la ligne du groupe, usermod ajoute le
# membre — sauf si le marqueur « usermod-sans-effet » est posé.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  case "$1 ${2:-}" in
    "groupadd --system") printf '%s:x:990:\n' "$3" >>"$GROUPS_DB" ;;
    "usermod -aG")
      [[ -e $TEST_TMP/usermod-sans-effet ]] && return 0
      local line
      line=$(grep "^$3:" "$GROUPS_DB")
      grep -v "^$3:" "$GROUPS_DB" >"$TEST_TMP/reste"
      if [[ $line == *: ]]; then printf '%s%s\n' "$line" "$4"; else printf '%s,%s\n' "$line" "$4"; fi >>"$TEST_TMP/reste"
      mv "$TEST_TMP/reste" "$GROUPS_DB" ;;
  esac
  return 0
}
count_calls() { grep -c -- "$1" "$CALLS" || true; }
line_of() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }
MODULE_NAME=essai

printf '%s\n' "== user_in_group =="
printf 'docker:x:986:u\nkvm:x:991:uu,autre\nvideo:x:44:autre,u\n' >"$GROUPS_DB"
assert_ok "membre unique → vrai" user_in_group docker
assert_fail "« uu » n'est pas « u » → faux" user_in_group kvm
assert_ok "membre en fin de liste → vrai" user_in_group video
assert_fail "groupe absent → faux" user_in_group inexistant
assert_eq "groupe absent → aucun message" "" "$(user_in_group inexistant 2>&1)"

printf '%s\n' "== ensure_user_in_group =="
printf 'kvm:x:991:\n' >"$GROUPS_DB"; : >"$CALLS"
assert_ok "groupe présent, non membre → réussit" ensure_user_in_group kvm
assert_eq "aucun groupadd" 0 "$(count_calls groupadd)"
assert_contains "usermod -aG kvm u" "$(cat "$CALLS")" "usermod -aG kvm u"
assert_ok "membre ensuite" user_in_group kvm
: >"$CALLS"
assert_ok "déjà membre → réussit" ensure_user_in_group kvm
assert_eq "déjà membre → aucun appel" 0 "$(wc -l <"$CALLS")"
: >"$GROUPS_DB"; : >"$CALLS"
assert_ok "groupe absent → réussit" ensure_user_in_group docker
assert_contains "groupe créé comme groupe système" "$(cat "$CALLS")" "groupadd --system docker"
assert_ok "groupe créé avant l'inscription" test "$(line_of groupadd)" -lt "$(line_of usermod)"
assert_ok "membre ensuite" user_in_group docker
printf 'video:x:44:\n' >"$GROUPS_DB"; touch "$TEST_TMP/usermod-sans-effet"
out=$(ensure_user_in_group video 2>&1); rc=$?
assert_ok "inscription qui ne se constate pas → échec" test "$rc" -ne 0
assert_contains "l'échec nomme le groupe" "$out" "groupe video"
rm -f "$TEST_TMP/usermod-sans-effet"
assert_fail "groupe manquant en argument → échec" ensure_user_in_group ""

printf '%s\n' "== group_relogin_step =="
printf 'kvm:x:991:u\ndocker:x:986:u\n' >"$GROUPS_DB"; : >"$MANUAL_STEPS_FILE"
printf 'u sudo' >"$SESSION"
out=$(group_relogin_step kvm 2>&1); rc=$?
assert_eq "session sans le groupe → sans erreur" 0 "$rc"
assert_contains "l'écart est signalé" "$out" "ne porte pas encore le groupe kvm"
assert_contains "étape manuelle déclarée" "$(cat "$MANUAL_STEPS_FILE")" "rouvrir la session"
assert_contains "l'étape nomme le groupe" "$(cat "$MANUAL_STEPS_FILE")" "groupe kvm"
group_relogin_step docker 2>/dev/null
assert_eq "deux groupes → deux lignes distinctes" 2 "$(wc -l <"$MANUAL_STEPS_FILE")"
: >"$MANUAL_STEPS_FILE"; printf 'u sudo kvm' >"$SESSION"
assert_ok "session à jour → réussit" group_relogin_step kvm
assert_eq "session à jour → aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"
printf 'kvm:x:991:autre\n' >"$GROUPS_DB"; printf 'u sudo' >"$SESSION"
assert_ok "non membre → réussit" group_relogin_step kvm
assert_eq "non membre → aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"

test_done
