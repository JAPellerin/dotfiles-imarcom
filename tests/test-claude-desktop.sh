#!/usr/bin/env bash
# tests/test-claude-desktop.sh — module claude-desktop avec des doublures
# (dpkg-query, getent et id lus dans des fichiers ; run_sudo qui journalise et
# simule apt-get install, usermod, groupadd et la copie vers un /etc du dossier
# temporaire ; apt_add_repo qui compte). Les fonctions du module sont appelées
# par module_call, chacune dans son sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
# shellcheck source=../lib/groups.sh
source "$DOTFILES_DIR/lib/groups.sh"

mkdir -p "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP" USER=u CLAUDE_DESKTOP_ETC="$TEST_TMP/racine"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
GROUPS_DB="$TEST_TMP/groups"; printf 'kvm:x:991:\n' >"$GROUPS_DB"
SESSION="$TEST_TMP/session-groups"; printf 'u sudo' >"$SESSION"
DEFAULT_FILE="$CLAUDE_DESKTOP_ETC/etc/default/claude-desktop"
MOD="$DOTFILES_DIR/modules/52-claude-desktop.sh"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/getent" <<'FAKE'
#!/usr/bin/env bash
[ "$1" = group ] || exit 2
grep "^$2:" "$FAKE_DIR/groups" || exit 2
FAKE
cat >"$TEST_TMP/bin/id" <<'FAKE'
#!/usr/bin/env bash
case ${1:-} in -nG) cat "$FAKE_DIR/session-groups"; printf '\n' ;; -un) printf 'u\n' ;; *) exit 1 ;; esac
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublures, héritées par les sous-shells de module_call.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a line
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  case "${args[0]} ${args[1]:-}" in
    "apt-get install")
      [[ -e $TEST_TMP/apt-refuse ]] && return 100
      for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done ;;
    "usermod -aG")
      line=$(grep "^${args[2]}:" "$GROUPS_DB"); grep -v "^${args[2]}:" "$GROUPS_DB" >"$TEST_TMP/reste"
      if [[ $line == *: ]]; then printf '%s%s\n' "$line" "${args[3]}"; else printf '%s,%s\n' "$line" "${args[3]}"; fi >>"$TEST_TMP/reste"
      mv "$TEST_TMP/reste" "$GROUPS_DB" ;;
    "groupadd --system") printf '%s:x:990:\n' "${args[2]}" >>"$GROUPS_DB" ;;
    install*) run "${args[@]}" ;;   # copie vers le /etc du dossier temporaire, sans sudo
  esac
  return 0
}
apt_add_repo() { printf 'apt_add_repo %s\n' "$*" >>"$CALLS"; }
export -f run_sudo apt_add_repo
export INSTALLED CALLS GROUPS_DB TEST_TMP
_APT_UPDATED=1; export _APT_UPDATED
count_calls() { grep -c -- "$1" "$CALLS" || true; }
line_of() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }
# Comme le runner (setup.sh) : chaque fonction dans son propre sous-shell.
mcall() { module_call "$MOD" "$1"; }

printf '%s\n' "== première application (sous-shells du runner) =="
assert_fail "module_check → à faire" mcall module_check
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_eq "réglage posé avec le contenu versionné" "$(cat "$DOTFILES_DIR/config/claude-desktop/claude-desktop.default")" "$(cat "$DEFAULT_FILE" 2>/dev/null)"
assert_contains "réglage : dépôt du paquet désactivé" "$(cat "$DEFAULT_FILE")" 'CLAUDE_DESKTOP_ADD_REPO="false"'
assert_ok "réglage posé avant le paquet" test "$(line_of "claude-desktop.default")" -lt "$(line_of 'apt-get install')"
assert_ok "dépôt déclaré avant le paquet" test "$(line_of apt_add_repo)" -lt "$(line_of 'apt-get install')"
assert_contains "dépôt d'Anthropic" "$(cat "$CALLS")" \
  "apt_add_repo claude-desktop https://downloads.claude.ai/claude-desktop/key.asc https://downloads.claude.ai/claude-desktop/apt/stable stable main"
assert_not_contains "recommandations non désactivées (QEMU pour Cowork)" "$(grep 'apt-get install' "$CALLS")" "no-install-recommends"
assert_contains "étape de connexion au résumé, malgré les sous-shells" "$(cat "$MANUAL_STEPS_FILE")" "se connecter avec le compte Anthropic"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "session sans le groupe signalée" "$out" "ne porte pas encore le groupe kvm"
assert_contains "utilisateur inscrit au groupe kvm" "$(cat "$CALLS")" "usermod -aG kvm u"
assert_eq "groupe kvm présent → aucun groupadd" 0 "$(count_calls groupadd)"
assert_contains "réouverture de session au résumé, nommant kvm" "$(cat "$MANUAL_STEPS_FILE")" "groupe kvm"
assert_ok "module_check → déjà fait (session sans le groupe : transitoire)" mcall module_check

printf '%s\n' "== réexécution =="
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"; printf 'u sudo kvm' >"$SESSION"
assert_ok "module_install réussit" mcall module_install
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucun appel système (paquet, réglage, groupe déjà là)" "apt_add_repo claude-desktop https://downloads.claude.ai/claude-desktop/key.asc https://downloads.claude.ai/claude-desktop/apt/stable stable main" "$(cat "$CALLS")"
assert_eq "paquet déjà là, session à jour → aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== réglage supprimé ou modifié =="
rm -f "$DEFAULT_FILE"
assert_fail "réglage absent → à faire" mcall module_check
assert_ok "module_install le rétablit" mcall module_install
assert_ok "module_check → déjà fait" mcall module_check
printf 'CLAUDE_DESKTOP_ADD_REPO="true"\n' >"$DEFAULT_FILE"
assert_fail "réglage au contenu différent → à faire" mcall module_check
assert_ok "module_install le rétablit" mcall module_install
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== installation du paquet en échec =="
grep -vx claude-desktop "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
: >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/apt-refuse"
assert_fail "module_install échoue" mcall module_install
assert_eq "aucune étape de connexion" "" "$(cat "$MANUAL_STEPS_FILE")"
rm -f "$TEST_TMP/apt-refuse"
assert_ok "après correction, module_install réussit" mcall module_install

printf '%s\n' "== groupe kvm absent =="
printf 'autre:x:1:\n' >"$GROUPS_DB"; : >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_ok "groupe créé avant l'inscription" test "$(line_of groupadd)" -lt "$(line_of usermod)"

printf '%s\n' "== sans virtualisation matérielle =="
assert_ok "module_configure ne regarde pas /dev/kvm : réussit" mcall module_configure

printf '%s\n' "== module_check : chacune de ses conditions =="
assert_ok "module_check → déjà fait" mcall module_check
grep -vx claude-desktop "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
assert_fail "paquet absent → à faire" mcall module_check
printf 'claude-desktop\n' >>"$INSTALLED"
printf 'kvm:x:991:autre\nautre:x:1:\n' >"$GROUPS_DB"
assert_fail "utilisateur hors de kvm → à faire" mcall module_check
printf 'kvm:x:991:autre,u\n' >"$GROUPS_DB"
assert_ok "module_check → déjà fait" mcall module_check

test_done
