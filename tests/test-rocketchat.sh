#!/usr/bin/env bash
# tests/test-rocketchat.sh — module rocketchat avec un HOME et une racine isolés
# et des doublures (dpkg-query lu dans un fichier ; github_release_asset_url,
# apt_install_deb_url, run_sudo et apparmor_parser qui journalisent, et échouent
# sur demande ; run_sudo copie vers le /opt et le /etc du dossier temporaire,
# sans sudo). Hors ligne : aucun appel à GitHub.
# Les fonctions du module sont appelées par module_call, chacune dans son
# sous-shell, comme le fait le runner.
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

export HOME="$TEST_TMP/home"
mkdir -p "$HOME" "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP" ROCKETCHAT_ROOT="$TEST_TMP/racine"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
SERVERS="$ROCKETCHAT_ROOT/opt/Rocket.Chat/resources/servers.json"
USER_SERVERS="$HOME/.config/Rocket.Chat/servers.json"
SRC="config/rocketchat/servers.json"
PROFILE="$ROCKETCHAT_ROOT/etc/apparmor.d/rocketchat-desktop"
PROFILE_SRC="config/rocketchat/apparmor-profile"
MOD="$DOTFILES_DIR/modules/61-rocketchat.sh"
DEB_URL="https://github.com/RocketChat/Rocket.Chat.Electron/releases/download/4.17.2/rocketchat-4.17.2-linux-amd64.deb"

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
export PATH="$TEST_TMP/bin:$PATH"

# Doublures, héritées par les sous-shells de module_call.
github_release_asset_url() {
  printf 'github_release_asset_url %s\n' "$*" >>"$CALLS"
  [[ -e $TEST_TMP/github-refuse ]] && { log_error "API GitHub injoignable pour $1"; return 1; }
  printf '%s\n' "$DEB_URL"
}
apt_install_deb_url() {
  printf 'apt_install_deb_url %s\n' "$*" >>"$CALLS"
  [[ -e $TEST_TMP/apt-refuse ]] && return 1
  printf '%s\n' "$2" >>"$INSTALLED"
}
run_sudo() {
  printf 'run_sudo %s\n' "$*" >>"$CALLS"
  [[ -e $TEST_TMP/sudo-refuse ]] && return 1
  run "$@"
}
export -f github_release_asset_url apt_install_deb_url run_sudo
export INSTALLED CALLS TEST_TMP DEB_URL
count_calls() { grep -c -- "$1" "$CALLS" || true; }
same_as_repo() { cmp -s -- "$DOTFILES_DIR/$SRC" "$SERVERS"; }
profile_as_repo() { cmp -s -- "$DOTFILES_DIR/$PROFILE_SRC" "$PROFILE"; }
uninstall() { grep -vx rocketchat "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"; }
# Comme le runner (setup.sh) : chaque fonction dans son propre sous-shell.
mcall() { module_call "$MOD" "$1"; }

printf '%s\n' "== liste de serveurs versionnée =="
assert_ok "JSON valide" jq -e . "$DOTFILES_DIR/$SRC"
assert_eq "désigne le serveur de l'entreprise" "https://rocketchat.imarcom.net" \
  "$(jq -r '[.[]] | .[0]' "$DOTFILES_DIR/$SRC")"
assert_eq "un seul serveur" 1 "$(jq 'length' "$DOTFILES_DIR/$SRC")"

printf '%s\n' "== profil AppArmor versionné =="
assert_contains "attaché au binaire, pas au script d'enveloppe" "$(cat "$DOTFILES_DIR/$PROFILE_SRC")" \
  "profile rocketchat-desktop /opt/Rocket.Chat/rocketchat-desktop.bin flags=(unconfined) {"
assert_contains "autorise les espaces de noms utilisateur" "$(cat "$DOTFILES_DIR/$PROFILE_SRC")" "  userns,"

printf '%s\n' "== première application (sous-shells du runner) =="
assert_fail "module_check → à faire" mcall module_check
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_contains "dépôt et motif du .deb amd64" "$(cat "$CALLS")" \
  'github_release_asset_url RocketChat/Rocket.Chat.Electron -linux-amd64\.deb$'
assert_contains "paquet rocketchat depuis l'URL trouvée" "$(cat "$CALLS")" "apt_install_deb_url $DEB_URL rocketchat"
assert_contains "étape de connexion au résumé, malgré les sous-shells" "$(cat "$MANUAL_STEPS_FILE")" "se connecter à rocketchat.imarcom.net"
assert_fail "paquet installé, liste de serveurs absente → à faire" mcall module_check
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_ok "liste de serveurs copiée, identique au dépôt" same_as_repo
assert_ok "profil AppArmor copié, identique au dépôt" profile_as_repo
assert_contains "profil chargé" "$(cat "$CALLS")" "apparmor_parser -r $PROFILE"
assert_fail "copie, pas un lien" test -L "$SERVERS"
assert_eq "rien sous ~/.config/Rocket.Chat" "" "$(ls -A "$HOME/.config/Rocket.Chat" 2>/dev/null)"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== premier lancement du client =="
# Le client lit ~/.config/Rocket.Chat/servers.json puis le supprime ; celui du
# paquet reste en place (loadUserServers / loadAppServers, design D2).
mkdir -p "$(dirname -- "$USER_SERVERS")"; printf '{}\n' >"$USER_SERVERS"; rm -f "$USER_SERVERS"
assert_ok "module_check → toujours déjà fait" mcall module_check
assert_ok "liste du paquet intacte" same_as_repo

printf '%s\n' "== réexécution =="
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
assert_ok "module_install réussit" mcall module_install
assert_ok "module_configure réussit" mcall module_configure
assert_eq "paquet et liste déjà là → aucun appel à GitHub, téléchargement ni sudo" "" "$(cat "$CALLS")"
assert_eq "aucune étape de connexion" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== liste de serveurs retirée =="
rm -f "$SERVERS"
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_configure la réécrit" mcall module_configure
assert_ok "identique au dépôt" same_as_repo
assert_ok "module_check → déjà fait" mcall module_check
assert_eq "toujours aucun appel à GitHub" 0 "$(count_calls github_release_asset_url)"

printf '%s\n' "== liste de serveurs différente =="
printf '{"Autre": "https://chat.example.com"}\n' >"$SERVERS"
assert_fail "contenu différent → à faire" mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_ok "remplacée par la version du dépôt" same_as_repo
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== profil AppArmor retiré ou différent =="
for etat in retiré différent; do
  if [[ $etat == retiré ]]; then rm -f "$PROFILE"; else printf 'profile autre {}\n' >"$PROFILE"; fi
  : >"$CALLS"
  assert_fail "profil $etat → à faire" mcall module_check
  assert_ok "module_configure réussit" mcall module_configure
  assert_ok "profil remis comme au dépôt" profile_as_repo
  assert_eq "profil rechargé" 1 "$(count_calls "^apparmor_parser -r $PROFILE")"
  assert_ok "module_check → déjà fait" mcall module_check
done

printf '%s\n' "== chargement du profil en échec =="
rm -f "$PROFILE"; touch "$TEST_TMP/parser-refuse"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure échoue" 1 "$rc"
assert_contains "échec nommé" "$out" "Chargement du profil AppArmor impossible"
assert_fail "profil non chargé retiré" test -e "$PROFILE"
assert_fail "module_check → à faire" mcall module_check
rm -f "$TEST_TMP/parser-refuse"; : >"$CALLS"
assert_ok "après correction, module_configure réussit" mcall module_configure
assert_eq "profil copié et chargé" 1 "$(count_calls "^apparmor_parser -r $PROFILE")"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== écriture système en échec =="
rm -f "$SERVERS"; touch "$TEST_TMP/sudo-refuse"
assert_fail "module_configure échoue" mcall module_configure
assert_fail "module_check → à faire" mcall module_check
rm -f "$TEST_TMP/sudo-refuse"
assert_ok "après correction, module_configure réussit" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== recherche de la release en échec =="
uninstall; : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/github-refuse"
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install échoue" 1 "$rc"
assert_contains "échec nommé" "$out" "RocketChat/Rocket.Chat.Electron"
assert_eq "aucun téléchargement" 0 "$(count_calls apt_install_deb_url)"
assert_eq "aucune étape de connexion" "" "$(cat "$MANUAL_STEPS_FILE")"
rm -f "$TEST_TMP/github-refuse"

printf '%s\n' "== installation du paquet en échec =="
touch "$TEST_TMP/apt-refuse"
assert_fail "module_install échoue" mcall module_install
assert_eq "aucune étape de connexion" "" "$(cat "$MANUAL_STEPS_FILE")"
rm -f "$TEST_TMP/apt-refuse"
assert_ok "après correction, module_install réussit" mcall module_install
assert_contains "étape de connexion déclarée" "$(cat "$MANUAL_STEPS_FILE")" "rocketchat.imarcom.net"

printf '%s\n' "== module_check : chacune de ses conditions =="
: >"$CALLS"
assert_ok "module_check → déjà fait" mcall module_check
uninstall
assert_fail "paquet absent → à faire" mcall module_check
printf 'rocketchat\n' >>"$INSTALLED"
assert_ok "paquet de retour → déjà fait" mcall module_check
rm -f "$SERVERS"
assert_fail "liste de serveurs absente → à faire" mcall module_check
assert_ok "module_configure la réécrit" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check
rm -f "$SERVERS"
printf '{"Autre": "https://chat.example.com"}\n' >"$SERVERS"
assert_fail "liste de serveurs différente → à faire" mcall module_check
assert_ok "module_configure la remplace" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check
rm -f "$PROFILE"
assert_fail "profil AppArmor absent → à faire" mcall module_check
assert_ok "module_configure le réécrit" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check
assert_eq "aucun appel à GitHub hors module_install" 0 "$(count_calls github_release_asset_url)"
assert_eq "aucun téléchargement hors module_install" 0 "$(count_calls apt_install_deb_url)"
test_done
