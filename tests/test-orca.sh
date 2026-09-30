#!/usr/bin/env bash
# tests/test-orca.sh — module orca avec des doublures (dpkg-query lu dans un
# fichier ; github_release_asset_url qui imprime une URL ou échoue selon un
# marqueur et compte ses appels ; apt_install_deb_url qui journalise et ajoute le
# paquet, ou échoue selon un marqueur ; sudo factice, run_sudo et
# install_system_file restent les vrais ; apparmor_parser qui trace et échoue sur
# marqueur ; racine ORCA_ROOT du test). Fonctions du module appelées par
# module_call, chacune dans son sous-shell, comme le fait le runner.
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

fake_sudo
export FAKE_DIR="$TEST_TMP" ORCA_ROOT="$TEST_TMP/racine"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
MOD="$DOTFILES_DIR/modules/53-orca.sh"
URL="https://github.com/stablyai/orca/releases/download/v1.4.217/orca-ide_1.4.217_amd64.deb"
PROFILE="$ORCA_ROOT/etc/apparmor.d/opt.Orca.orca-ide"
PROFILE_SRC="$DOTFILES_DIR/config/orca/apparmor-profile"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/apparmor_parser" <<'FAKE'
#!/usr/bin/env bash
printf 'apparmor_parser %s\n' "$*" >>"$FAKE_DIR/calls"
[[ ! -e $FAKE_DIR/parser-refuse ]]
FAKE
chmod +x "$TEST_TMP/bin/"*

# Doublures : fonctions du shell, héritées telles quelles par les sous-shells
# ( … ) de module_call, sans export.
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
mcall() { module_call "$MOD" "$1"; }
meta() { bash -c 'source "$1"; printf "%s" "${!2:-}"' _ "$MOD" "$1"; }

printf '%s\n' "== métadonnées =="
assert_eq "groupe apps" "apps" "$(meta MODULE_GROUP)"
assert_eq "session graphique requise" "1" "$(meta MODULE_NEEDS_GUI)"
assert_eq "dépend de base" "base" "$(meta MODULE_DEPS)"
assert_ok "métadonnées acceptées par module_meta" module_meta "$MOD"
assert_contains "description qui lève l'ambiguïté avec le lecteur d'écran" "$(meta MODULE_DESC)" "IDE d'agents"

printf '%s\n' "== profil AppArmor du dépôt =="
assert_ok "attaché à l'exécutable ELF" grep -q '^profile /opt/Orca/orca-ide flags=(unconfined) {' "$PROFILE_SRC"
assert_ok "autorise les espaces de noms utilisateur" grep -qx '  userns,' "$PROFILE_SRC"

printf '%s\n' "== première application (sous-shells du runner) =="
assert_fail "module_check → à faire" mcall module_check
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_contains "dépôt et motif passés au helper" "$(cat "$CALLS")" \
  'github_release_asset_url stablyai/orca _amd64\.deb$'
assert_contains "URL trouvée passée à l'installation, paquet orca-ide" "$(cat "$CALLS")" \
  "apt_install_deb_url $URL orca-ide"
assert_contains "URL au journal" "$(cat "$LOG_FILE")" "$URL"
assert_contains "étape des dépôts au résumé, malgré les sous-shells" "$(cat "$MANUAL_STEPS_FILE")" "ajouter ses dépôts de travail"
assert_fail "paquet seul → encore à faire (profil absent)" mcall module_check
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_ok "profil écrit tel quel" cmp -s "$PROFILE_SRC" "$PROFILE"
assert_eq "profil en 0644" 644 "$(stat -c %a "$PROFILE")"
assert_eq "profil chargé une fois" 1 "$(count_calls "^apparmor_parser -r $PROFILE")"
assert_fail "pas sous le nom du profil du paquet" test -e "$ORCA_ROOT/etc/apparmor.d/orca-ide"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== relance =="
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
assert_ok "module_install réussit" mcall module_install
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucun appel à GitHub, téléchargement ni chargement" "" "$(cat "$CALLS")"
assert_eq "aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== profil modifié ou retiré =="
printf '# autre\n' >"$PROFILE"
assert_fail "profil différent → à faire" mcall module_check
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_ok "profil réécrit" cmp -s "$PROFILE_SRC" "$PROFILE"
assert_eq "profil rechargé" 1 "$(count_calls "^apparmor_parser -r $PROFILE")"
rm -f "$PROFILE"
assert_fail "profil absent → à faire" mcall module_check
mcall module_configure >/dev/null 2>&1
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== chargement du profil en échec =="
rm -f "$PROFILE"; touch "$TEST_TMP/parser-refuse"
out=$(mcall module_configure 2>&1); rc=$?
assert_ok "module_configure échoue" test "$rc" -ne 0
assert_contains "échec qui nomme le profil" "$out" "$PROFILE"
assert_fail "profil retiré" test -e "$PROFILE"
assert_fail "module_check → à faire" mcall module_check
rm -f "$TEST_TMP/parser-refuse"
assert_ok "après correction, module_configure réussit" mcall module_configure

printf '%s\n' "== profil du paquet au même attachement =="
touch "$ORCA_ROOT/etc/apparmor.d/orca-ide"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "doublon signalé en le nommant" "$out" "$ORCA_ROOT/etc/apparmor.d/orca-ide"
assert_ok "doublon laissé en place" test -e "$ORCA_ROOT/etc/apparmor.d/orca-ide"
rm -f "$ORCA_ROOT/etc/apparmor.d/orca-ide"
out=$(mcall module_configure 2>&1)
assert_not_contains "sans doublon : aucun avertissement" "$out" "Profil AppArmor du paquet"

printf '%s\n' "== recherche de l'URL en échec =="
: >"$INSTALLED"; : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/github-refuse"
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
assert_ok "paquet et profil → déjà fait" mcall module_check

test_done
