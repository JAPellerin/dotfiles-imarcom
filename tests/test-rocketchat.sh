#!/usr/bin/env bash
# tests/test-rocketchat.sh — module rocketchat avec un HOME et une racine isolés
# et des doublures (dpkg-query lu dans un fichier ; github_release_asset_url,
# apt_install_deb_url, run_sudo et apparmor_parser qui journalisent, et échouent
# sur demande ; run_sudo copie vers le /opt et le /etc du dossier temporaire,
# sans sudo). Hors ligne : aucun appel à GitHub.
# Connexion guidée (guided_login réel) : op (session et lectures), wl-copy
# (presse-papiers dans un fichier) et un client factice qui, sur demande, écrit
# un config.json « connecté » pendant qu'il tourne, comme le vrai ; has_gui et
# ui_choose en fonctions.
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
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
# shellcheck source=../lib/connexion.sh
source "$DOTFILES_DIR/lib/connexion.sh"

export HOME="$TEST_TMP/home"
mkdir -p "$HOME" "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP" ROCKETCHAT_ROOT="$TEST_TMP/racine"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
SERVERS="$ROCKETCHAT_ROOT/opt/Rocket.Chat/resources/servers.json"
USER_SERVERS="$HOME/.config/Rocket.Chat/servers.json"
SRC="config/rocketchat/servers.json"
PROFILE="$ROCKETCHAT_ROOT/etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin"
PROFILE_SRC="config/rocketchat/apparmor-profile"
MOD="$DOTFILES_DIR/modules/61-rocketchat.sh"
# Configuration du client : chemin exporté avant tout module_call (design D10).
export ROCKETCHAT_CONFIG="$TEST_TMP/rocketchat/config.json"
# Attente longue par défaut : le parcours rend la main dès la connexion constatée,
# et une machine chargée (suite complète) ne doit pas la faire expirer ; le cas
# « Passer » la raccourcit à 1 s.
export CONNEXION_WAIT_SECONDS=10 CONNEXION_WAIT_INTERVAL=0.1
CLIENT="$ROCKETCHAT_ROOT/opt/Rocket.Chat/rocketchat-desktop"
CLIP="$TEST_TMP/clipboard"
SECRET="Rc-S3cr3t-7q"; USER_NAME="jpellerin"
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
# op : session si $FAKE_DIR/session ; lectures tracées ; identifiant illisible
# si $FAKE_DIR/op-user-refuse.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read) printf 'op read %s\n' "${*: -1}" >>"$FAKE_DIR/calls"
        case ${*: -1} in
          op://Imarcom/RocketChat/password) printf 'Rc-S3cr3t-7q' ;;
          op://Imarcom/RocketChat/username)
            [[ -e $FAKE_DIR/op-user-refuse ]] && { echo "[ERROR] champ illisible" >&2; exit 1; }
            printf 'jpellerin' ;;
          *) echo "[ERROR] item introuvable" >&2; exit 1 ;;
        esac ;;
esac
FAKE
# wl-copy : presse-papiers dans un fichier.
cat >"$TEST_TMP/bin/wl-copy" <<'FAKE'
#!/usr/bin/env bash
if [[ ${1:-} == --clear ]]; then : >"$FAKE_DIR/clipboard"; else cat >"$FAKE_DIR/clipboard"; fi
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
# Client factice, à l'emplacement de la commande du lanceur (sous la racine du
# test) : trace son lancement ; si $FAKE_DIR/client-connecte existe, écrit peu
# après le config.json « connecté », pendant qu'il tourne. Lancé par
# open_detached (setsid), jamais par un « & » du test.
mkdir -p "$(dirname -- "$CLIENT")"
cat >"$CLIENT" <<'FAKE'
#!/usr/bin/env bash
printf 'rocketchat-desktop lancé\n' >>"$FAKE_DIR/calls"
if [[ -e $FAKE_DIR/client-connecte ]]; then
  sleep 0.3
  mkdir -p "$(dirname -- "$ROCKETCHAT_CONFIG")"
  printf '{"servers":[{"url":"https://rocketchat.imarcom.net/","userLoggedIn":true}]}\n' >"$ROCKETCHAT_CONFIG"
fi
FAKE
chmod +x "$CLIENT"

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
# Session graphique et réponse au choix « Continuer / Passer » de guided_login.
has_gui() { return 0; }
ui_choose() { printf '%s\n' "${FAKE_CHOICE:-Passer (étape manuelle)}"; }
# write_config <json> : écrit la configuration du client.
write_config() { mkdir -p "$(dirname -- "$ROCKETCHAT_CONFIG")"; printf '%s\n' "$1" >"$ROCKETCHAT_CONFIG"; }
connected() { write_config '{"servers":[{"url":"https://rocketchat.imarcom.net/","userLoggedIn":true}]}'; }
touch "$TEST_TMP/session"
# Client connecté d'emblée : les cas qui ne portent pas sur la connexion ne
# lancent pas le parcours (il n'attend alors rien).
connected

printf '%s\n' "== dépendances =="
# Lu dans un bash à part : le module chargé dans un sous-shell du test ferait
# croire à shellcheck que DOTFILES_DIR et TEST_TMP y sont modifiés.
# shellcheck disable=SC2016  # développé par le bash lancé, pas ici
assert_eq "dépend de base et de 1password (lancé seul, 1password passe avant)" "base 1password" \
  "$(bash -c 'source "$1"; printf "%s" "$MODULE_DEPS"' _ "$MOD")"

printf '%s\n' "== liste de serveurs versionnée =="
assert_ok "JSON valide" jq -e . "$DOTFILES_DIR/$SRC"
assert_eq "désigne le serveur de l'entreprise" "https://rocketchat.imarcom.net" \
  "$(jq -r '[.[]] | .[0]' "$DOTFILES_DIR/$SRC")"
assert_eq "un seul serveur" 1 "$(jq 'length' "$DOTFILES_DIR/$SRC")"

printf '%s\n' "== profil AppArmor versionné =="
assert_contains "attaché au binaire, pas au script d'enveloppe" "$(cat "$DOTFILES_DIR/$PROFILE_SRC")" \
  "profile /opt/Rocket.Chat/rocketchat-desktop.bin flags=(unconfined) {"
assert_contains "autorise les espaces de noms utilisateur" "$(cat "$DOTFILES_DIR/$PROFILE_SRC")" "  userns,"

printf '%s\n' "== première application (sous-shells du runner) =="
assert_fail "module_check → à faire" mcall module_check
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_contains "dépôt et motif du .deb amd64" "$(cat "$CALLS")" \
  'github_release_asset_url RocketChat/Rocket.Chat.Electron -linux-amd64\.deb$'
assert_contains "paquet rocketchat depuis l'URL trouvée" "$(cat "$CALLS")" "apt_install_deb_url $DEB_URL rocketchat"
assert_eq "aucune étape déclarée par module_install (la connexion est guidée ensuite)" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_fail "paquet installé, liste de serveurs absente → à faire" mcall module_check
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_ok "liste de serveurs copiée, identique au dépôt" same_as_repo
assert_ok "profil AppArmor copié, identique au dépôt" profile_as_repo
assert_contains "profil chargé" "$(cat "$CALLS")" "apparmor_parser -r $PROFILE"
# Le postrm du paquet supprime /etc/apparmor.d/rocketchat-desktop à chaque
# mise à jour (design D6).
assert_fail "pas sous le nom que retire le postrm du paquet" test -e "$ROCKETCHAT_ROOT/etc/apparmor.d/rocketchat-desktop"
assert_fail "copie, pas un lien" test -L "$SERVERS"
assert_fail "aucun servers.json sous ~/.config/Rocket.Chat" test -e "$USER_SERVERS"
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
assert_eq "aucune étape déclarée par module_install" "" "$(cat "$MANUAL_STEPS_FILE")"

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

printf '%s\n' "== sonde de connexion =="
probe() { mcall _rocketchat_logged_in; }
connected
assert_ok "serveur de l'entreprise connecté, URL avec « / » final → vrai" probe
write_config '{"servers":[{"url":"https://rocketchat.imarcom.net","userLoggedIn":true}]}'
assert_ok "URL sans « / » final → vrai" probe
write_config '{"servers":[{"url":"https://rocketchat.imarcom.net/","userLoggedIn":false}]}'
assert_fail "userLoggedIn false → faux" probe
write_config '{"servers":[{"url":"https://chat.example.com/","userLoggedIn":true}]}'
assert_fail "autre serveur seulement → faux" probe
write_config '{"servers":[{"url":"https://chat.example.com/","userLoggedIn":true},{"url":"https://rocketchat.imarcom.net/","userLoggedIn":true}]}'
assert_ok "plusieurs serveurs dont celui de l'entreprise → vrai" probe
write_config '{"currentView":"server"}'
assert_fail ".servers absent → faux" probe
write_config '{"servers":[{"url":null,"userLoggedIn":true}]}'
assert_fail "url nulle → faux" probe
write_config '{pas du json'
assert_fail "JSON invalide → faux" probe
out=$(probe 2>&1)
assert_eq "JSON invalide : rien d'affiché" "" "$out"
rm -f "$ROCKETCHAT_CONFIG"
assert_fail "fichier absent → faux" probe
mkdir -p "$TEST_TMP/xdg/Rocket.Chat"
printf '{"servers":[{"url":"https://rocketchat.imarcom.net/","userLoggedIn":true}]}\n' >"$TEST_TMP/xdg/Rocket.Chat/config.json"
# shellcheck disable=SC2016  # développé par le bash lancé, pas ici
assert_ok "chemin par défaut sous XDG_CONFIG_HOME" \
  env -u ROCKETCHAT_CONFIG XDG_CONFIG_HOME="$TEST_TMP/xdg" bash -c \
  'source "$1"; source "$2"; _rocketchat_logged_in' _ "$DOTFILES_DIR/lib/core.sh" "$MOD"

printf '%s\n' "== module_check et connexion =="
connected
assert_ok "installé, fichiers en place, connecté → déjà fait" mcall module_check
write_config '{"servers":[{"url":"https://rocketchat.imarcom.net/","userLoggedIn":false}]}'
assert_fail "installé, fichiers en place, pas connecté → à faire" mcall module_check

# reset_login : pas connecté, presse-papiers, étapes, appels et journal remis à zéro.
reset_login() {
  rm -f "$ROCKETCHAT_CONFIG" "$CLIP" "$TEST_TMP"/{client-connecte,op-user-refuse}
  touch "$TEST_TMP/session"; : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; : >"$LOG_FILE"
}

printf '%s\n' "== connexion guidée réussie =="
reset_login; touch "$TEST_TMP/client-connecte"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "client lancé" "$(cat "$CALLS")" "rocketchat-desktop lancé"
assert_contains "mot de passe lu dans 1Password" "$(cat "$CALLS")" "op read op://Imarcom/RocketChat/password"
assert_contains "identifiant affiché" "$out" "Identifiant : $USER_NAME"
assert_not_contains "mot de passe absent de la sortie" "$out" "$SECRET"
assert_not_contains "mot de passe absent du journal" "$(cat "$LOG_FILE")" "$SECRET"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP" 2>/dev/null)"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== déjà connecté =="
reset_login; connected
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_eq "client non lancé" 0 "$(count_calls 'rocketchat-desktop lancé')"
assert_not_contains "aucune ouverture tracée au journal" "$(cat "$LOG_FILE")" "(détaché)"
assert_contains "déjà fait annoncé" "$out" "Rocket.Chat : déjà fait"

printf '%s\n' "== sans session 1Password =="
reset_login; rm -f "$TEST_TMP/session"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit quand même" 0 "$rc"
assert_contains "étape de connexion au résumé" "$(cat "$MANUAL_STEPS_FILE")" "se connecter à rocketchat.imarcom.net"
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_eq "client non lancé" 0 "$(count_calls 'rocketchat-desktop lancé')"
assert_fail "module_check → à faire" mcall module_check

printf '%s\n' "== passer =="
reset_login
out=$(CONNEXION_WAIT_SECONDS=1 FAKE_CHOICE="Passer (étape manuelle)" mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "client lancé" "$(cat "$CALLS")" "rocketchat-desktop lancé"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP" 2>/dev/null)"
assert_contains "étape de connexion au résumé" "$(cat "$MANUAL_STEPS_FILE")" "se connecter à rocketchat.imarcom.net"
assert_not_contains "mot de passe absent du journal" "$(cat "$LOG_FILE")" "$SECRET"
assert_fail "module_check → à faire" mcall module_check

printf '%s\n' "== identifiant illisible =="
reset_login; touch "$TEST_TMP/client-connecte" "$TEST_TMP/op-user-refuse"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "avertissement sur l'identifiant" "$out" "op://Imarcom/RocketChat/username"
assert_not_contains "aucun identifiant affiché" "$out" "Identifiant :"
assert_contains "client lancé quand même" "$(cat "$CALLS")" "rocketchat-desktop lancé"
assert_eq "connexion constatée, aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP" 2>/dev/null)"
test_done
