#!/usr/bin/env bash
# tests/test-obsidian.sh — module obsidian avec des doublures (dpkg-query lu dans
# un fichier ; github_release_asset_url qui imprime une URL ou échoue selon un
# marqueur et compte ses appels ; apt_install_deb_url qui journalise et ajoute le
# paquet, ou échoue selon un marqueur). Les fonctions du module sont appelées par
# module_call, chacune dans son sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

mkdir -p "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
MOD="$DOTFILES_DIR/modules/60-obsidian.sh"
URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.13.7/obsidian_1.13.7_amd64.deb"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublures : fonctions et variables du shell, héritées telles quelles par les
# sous-shells ( … ) de module_call, sans export.
github_release_asset_url() {
  printf 'github_release_asset_url %s %s\n' "$1" "$2" >>"$CALLS"
  [[ -e $TEST_TMP/github-refuse ]] && { log_error "API GitHub injoignable"; return 1; }
  printf '%s\n' "$URL"
}
apt_install_deb_url() {
  printf 'apt_install_deb_url %s %s\n' "$1" "$2" >>"$CALLS"
  [[ -e $TEST_TMP/deb-refuse ]] && return 1
  printf '%s\n' "$2" >>"$INSTALLED"
}
count_calls() { grep -c -- "$1" "$CALLS" || true; }
# Comme le runner (setup.sh) : chaque fonction dans son propre sous-shell.
mcall() { module_call "$MOD" "$1"; }

printf '%s\n' "== première application (sous-shells du runner) =="
assert_fail "module_check → à faire" mcall module_check
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_contains "dépôt et motif passés au helper" "$(cat "$CALLS")" \
  'github_release_asset_url obsidianmd/obsidian-releases _amd64\.deb$'
assert_contains "URL trouvée passée à l'installation, paquet obsidian" "$(cat "$CALLS")" \
  "apt_install_deb_url $URL obsidian"
assert_contains "URL au journal" "$(cat "$LOG_FILE")" "$URL"
assert_contains "étape du coffre au résumé, malgré les sous-shells" "$(cat "$MANUAL_STEPS_FILE")" "ouvrir ou synchroniser son coffre"
assert_ok "module_configure réussit" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== déjà installé =="
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
assert_ok "module_install réussit" mcall module_install
assert_eq "aucun appel à GitHub" 0 "$(count_calls github_release_asset_url)"
assert_eq "aucun téléchargement" 0 "$(count_calls apt_install_deb_url)"
assert_eq "aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== recherche de l'URL en échec =="
: >"$INSTALLED"; : >"$CALLS"; touch "$TEST_TMP/github-refuse"
out=$(mcall module_install 2>&1); rc=$?
assert_ok "module_install échoue" test "$rc" -ne 0
assert_contains "erreur du helper transmise, non masquée" "$out" "API GitHub injoignable"
assert_eq "aucun téléchargement" 0 "$(count_calls apt_install_deb_url)"
assert_eq "aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"
rm -f "$TEST_TMP/github-refuse"

printf '%s\n' "== installation du paquet en échec =="
: >"$CALLS"; touch "$TEST_TMP/deb-refuse"
assert_fail "module_install échoue" mcall module_install
assert_eq "aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_fail "module_check → à faire" mcall module_check
rm -f "$TEST_TMP/deb-refuse"
assert_ok "après correction, module_install réussit" mcall module_install

printf '%s\n' "== module_check : le paquet =="
assert_ok "paquet présent → déjà fait" mcall module_check
: >"$INSTALLED"
assert_fail "paquet absent → à faire" mcall module_check

test_done
