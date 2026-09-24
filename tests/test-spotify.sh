#!/usr/bin/env bash
# tests/test-spotify.sh — module spotify avec des doublures (dpkg-query lu dans
# un fichier ; run_sudo qui journalise et simule apt-get install et la copie vers
# un /etc du dossier temporaire ; apt_add_repo qui compte). Les fonctions du module sont appelées par module_call, chacune
# dans son sous-shell, comme le fait le runner.
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

mkdir -p "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP" SPOTIFY_ETC="$TEST_TMP/racine"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
LIST_FILE="$SPOTIFY_ETC/etc/apt/sources.list.d/spotify.list"
LIST_SRC="$DOTFILES_DIR/config/spotify/spotify.list"
MOD="$DOTFILES_DIR/modules/63-spotify.sh"
REPO_CALL="apt_add_repo spotify https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc https://repository.spotify.com stable non-free"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublures, héritées par les sous-shells de module_call.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  case "${args[0]} ${args[1]:-}" in
    "apt-get install")
      [[ -e $TEST_TMP/apt-refuse ]] && return 100
      for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done ;;
    install*) run "${args[@]}" ;;   # copie vers le /etc du dossier temporaire, sans sudo
  esac
  return 0
}
apt_add_repo() { printf 'apt_add_repo %s\n' "$*" >>"$CALLS"; }
export -f run_sudo apt_add_repo
export INSTALLED CALLS TEST_TMP
_APT_UPDATED=1; export _APT_UPDATED
line_of() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }
# Comme le runner (setup.sh) : chaque fonction dans son propre sous-shell.
mcall() { module_call "$MOD" "$1"; }

printf '%s\n' "== première application (sous-shells du runner) =="
assert_fail "module_check → à faire" mcall module_check
mcall module_install >/dev/null 2>&1; rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_eq "spotify.list posé avec le contenu versionné" "$(cat "$LIST_SRC")" "$(cat "$LIST_FILE" 2>/dev/null)"
assert_fail "spotify.list : aucune entrée de dépôt" grep -qE '^[[:space:]]*deb' "$LIST_FILE"
assert_ok "spotify.list posé avant le dépôt" test "$(line_of spotify.list)" -lt "$(line_of apt_add_repo)"
assert_ok "spotify.list posé avant le paquet" test "$(line_of spotify.list)" -lt "$(line_of 'apt-get install')"
assert_contains "dépôt de Spotify, clé et suite stable non-free" "$(cat "$CALLS")" "$REPO_CALL"
assert_ok "dépôt déclaré avant le paquet" test "$(line_of apt_add_repo)" -lt "$(line_of 'apt-get install')"
assert_contains "paquet spotify-client installé" "$(cat "$INSTALLED")" "spotify-client"
assert_contains "étape de connexion au résumé, malgré les sous-shells" "$(cat "$MANUAL_STEPS_FILE")" "se connecter"
assert_ok "module_configure réussit" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== déjà installé =="
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
assert_ok "module_install réussit" mcall module_install
assert_eq "rien de réécrit, aucun apt-get install" "$REPO_CALL" "$(cat "$CALLS")"
assert_eq "paquet déjà là → aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== spotify.list supprimé ou modifié =="
rm -f "$LIST_FILE"
assert_fail "spotify.list absent → à faire" mcall module_check
assert_ok "module_install le rétablit" mcall module_install
assert_ok "module_check → déjà fait" mcall module_check
printf 'deb https://repository.spotify.com stable non-free\n' >"$LIST_FILE"
assert_fail "spotify.list réécrit par le paquet → à faire" mcall module_check
assert_ok "module_install le rétablit" mcall module_install
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== installation du paquet en échec =="
: >"$INSTALLED"; : >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/apt-refuse"
assert_fail "module_install échoue" mcall module_install
assert_eq "aucune étape de connexion" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_fail "module_check → à faire" mcall module_check
rm -f "$TEST_TMP/apt-refuse"
assert_ok "après correction, module_install réussit" mcall module_install

printf '%s\n' "== module_check sur le paquet =="
assert_ok "paquet présent → déjà fait" mcall module_check
: >"$INSTALLED"
assert_fail "paquet absent → à faire" mcall module_check

test_done
