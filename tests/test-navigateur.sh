#!/usr/bin/env bash
# tests/test-navigateur.sh — module navigateur avec un HOME isolé, /etc et les
# dossiers apt dans le dossier temporaire, et des doublures : dpkg-query (liste
# + versions), apt-get (marque installé/retiré), snap, xdg-settings, gum
# (réponses scriptées), curl (clés factices), op (graine factice), wl-copy,
# brave-browser, sudo. install, cmp et jq réels. Aucun réseau.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

command -v jq >/dev/null 2>&1 || { printf 'jq absent : test sauté.\n'; exit 0; }

# --- Environnement isolé et doublures -------------------------------------------------------
export HOME="$TEST_TMP/home"
mkdir -p "$HOME"
export FAKE_DIR="$TEST_TMP"
EVENTS="$TEST_TMP/events"   # ordre des questions (gum) et des commandes apt-get
fake_sudo
# dpkg-query : « paquet<TAB>version » par ligne dans $FAKE_DIR/installed.
cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
pkg=${*: -1}
line=$(grep -P "^${pkg}\t" "$FAKE_DIR/installed" 2>/dev/null) || exit 1
case $* in
  *Version*) printf '%s' "${line#*	}" ;;
  *)         printf 'install ok installed' ;;
esac
FAKE
# apt-get : journalise ; install marque les paquets installés (firefox → version Mozilla), remove les retire.
cat >"$TEST_TMP/bin/apt-get" <<'FAKE'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$FAKE_DIR/events"
cmd=$1; shift
pkgs=()
for a in "$@"; do [[ $a == -* ]] || pkgs+=("$a"); done
case $cmd in
  install) for p in "${pkgs[@]}"; do
             sed -i "/^$p\t/d" "$FAKE_DIR/installed"
             v=1.0; [[ $p == firefox ]] && v=154.0
             printf '%s\t%s\n' "$p" "$v" >>"$FAKE_DIR/installed"
           done ;;
  remove)  for p in "${pkgs[@]}"; do sed -i "/^$p\t/d" "$FAKE_DIR/installed"; done ;;
esac
exit 0
FAKE
# snap : le snap firefox existe si $FAKE_DIR/snap-firefox existe.
cat >"$TEST_TMP/bin/snap" <<'FAKE'
#!/usr/bin/env bash
printf 'snap %s\n' "$*" >>"$FAKE_DIR/events"
case "$1 $2" in
  "list firefox") [[ -f $FAKE_DIR/snap-firefox ]] ;;
  "remove firefox") rm -f "$FAKE_DIR/snap-firefox" ;;
esac
FAKE
# xdg-settings : défaut dans $FAKE_DIR/default-browser.
cat >"$TEST_TMP/bin/xdg-settings" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  get) cat "$FAKE_DIR/default-browser" 2>/dev/null ;;
  set) printf '%s\n' "$3" >"$FAKE_DIR/default-browser" ;;
esac
FAKE
# gum : réponses scriptées selon l'en-tête ; chaque question est journalisée.
cat >"$TEST_TMP/bin/gum" <<'FAKE'
#!/usr/bin/env bash
[[ $1 == choose ]] || exit 0
header=""; for ((i = 1; i <= $#; i++)); do [[ ${!i} == --header ]] && { j=$((i + 1)); header=${!j}; }; done
printf 'gum %s\n' "$header" >>"$FAKE_DIR/events"
printf '%s\n' "$*" >>"$FAKE_DIR/gum-args"
case $header in
  Navigateurs*)  printf '%s\n' "$*" >>"$FAKE_DIR/gum-multi"; [[ -n ${FAKE_BROWSERS:-} ]] && printf '%b\n' "$FAKE_BROWSERS" ;;
  Langue*)       printf '%s\n' "${FAKE_LANG:-Anglais}" ;;
  Navigateur\ par*) printf '%s\n' "${FAKE_DEFAULT:-Brave}" ;;
  Brave\ Sync*)  printf '%s\n' "${FAKE_SYNC:-Passer (étape manuelle)}" ;;
esac
exit "${FAKE_GUM_RC:-0}"
FAKE
# curl : clé factice (binaire ou armurée selon l'URL) écrite dans le fichier -o.
cat >"$TEST_TMP/bin/curl" <<'FAKE'
#!/usr/bin/env bash
out=""; url=""
while (( $# )); do case $1 in -o) out=$2; shift ;; -*) ;; *) url=$1 ;; esac; shift; done
if [[ $url == *.gpg && $url != *packages.mozilla.org* ]]; then printf 'cle-binaire' >"$out"
else printf -- '-----BEGIN PGP PUBLIC KEY BLOCK-----\nfausse\n-----END PGP PUBLIC KEY BLOCK-----\n' >"$out"; fi
FAKE
# op : session si $FAKE_DIR/session ; read renvoie la note (25 mots) et compte les lectures.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
printf 'op %s\n' "$*" >>"$FAKE_DIR/events"
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read) [[ ${*: -1} == "op://Imarcom/Brave Sync Code/notesPlain" ]] || { echo "[ERROR] item introuvable" >&2; exit 1; }
        [[ -f $FAKE_DIR/note ]] || { echo "[ERROR] item introuvable" >&2; exit 1; }
        cat "$FAKE_DIR/note" ;;
esac
FAKE
# wl-copy : presse-papiers dans un fichier.
cat >"$TEST_TMP/bin/wl-copy" <<'FAKE'
#!/usr/bin/env bash
if [[ ${1:-} == --clear ]]; then : >"$FAKE_DIR/clipboard"; else cat >"$FAKE_DIR/clipboard"; fi
FAKE
# brave-browser : journalise l'URL ouverte.
cat >"$TEST_TMP/bin/brave-browser" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_DIR/brave.log"
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

export NAV_ETC="$TEST_TMP/root" APT_KEYRINGS_DIR="$TEST_TMP/root/etc/apt/keyrings" APT_SOURCES_DIR="$TEST_TMP/root/etc/apt/sources.list.d"
export NAV_BRAVE_PREFS="$TEST_TMP/prefs.json" NAV_WAIT_SECONDS=3 NAV_WAIT_INTERVAL=0.1
export OP_SESSION_FILE="$TEST_TMP/op-session"
mkdir -p "$APT_SOURCES_DIR"
# shellcheck source=../modules/25-navigateur.sh
source "$DOTFILES_DIR/modules/25-navigateur.sh"

# reset [paquets installés…] : remet l'environnement à zéro (lignes « paquet<TAB>version »).
reset() {
  : >"$EVENTS"; : >"$TEST_TMP/installed"; rm -rf "$NAV_ETC" "$TEST_TMP"/{default-browser,snap-firefox,session,note,clipboard,brave.log,prefs.json,gum-multi,gum-args}
  mkdir -p "$APT_SOURCES_DIR"; : >"$MANUAL_STEPS_FILE"; _APT_UPDATED=1
  local p; for p in "$@"; do printf '%b\n' "$p" >>"$TEST_TMP/installed"; done
}
events() { grep -c -- "$1" "$EVENTS" || true; }
# questions_first : toutes les lignes gum précèdent la première ligne apt-get.
questions_first() { [[ $(grep -n '^gum' "$EVENTS" | tail -1 | cut -d: -f1) -lt $(grep -n '^apt-get' "$EVENTS" | head -1 | cut -d: -f1) ]]; }

printf '%s\n' "== module_check et métadonnées =="
assert_fail "module_check : toujours à faire" module_check
meta=$(module_meta "$DOTFILES_DIR/modules/25-navigateur.sh")
assert_eq "métadonnées valides (groupe apps, deps, GUI)" "navigateur|$MODULE_DESC|apps|base,1password|1" "$meta"

printf '%s\n' "== première exécution : Brave + Firefox (français), questions avant apt =="
reset 'firefox\t1:1snap1-0ubuntu3'; touch "$TEST_TMP/snap-firefox"
export LANG=en_CA.UTF-8
FAKE_BROWSERS='Brave\nFirefox' FAKE_LANG=Français FAKE_DEFAULT=Brave module_install >/dev/null 2>&1; rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_ok "les questions (navigateurs, langue, défaut) précèdent tout apt-get" questions_first
assert_eq "trois questions posées, dans l'ordre" "gum Navigateurs à installer (Espace : cocher, Entrée : valider)
gum Langue de Firefox (Brave et Chrome suivent celle du système)
gum Navigateur par défaut" "$(grep '^gum' "$EVENTS")"
assert_contains "option « Comme Ubuntu » affiche la langue détectée" "$(cat "$TEST_TMP/gum-args")" "Comme Ubuntu (en)"
assert_file "dépôt Brave (.sources)" "$APT_SOURCES_DIR/brave-browser.sources"
assert_file "clé Brave binaire (.gpg)" "$APT_KEYRINGS_DIR/brave-browser.gpg"
assert_file "dépôt Mozilla (.sources)" "$APT_SOURCES_DIR/mozilla.sources"
assert_file "clé Mozilla armurée (.asc)" "$APT_KEYRINGS_DIR/mozilla.asc"
assert_contains "suite mozilla" "$(cat "$APT_SOURCES_DIR/mozilla.sources")" "Suites: mozilla"
assert_eq "épinglage Mozilla en place" "$(cat "$DOTFILES_DIR/config/navigateur/mozilla.pref")" "$(cat "$NAV_ETC/etc/apt/preferences.d/mozilla")"
assert_eq "brave-browser installé" 1 "$(events 'apt-get install -y -q brave-browser')"
assert_eq "firefox : apt_install_pinned (paquet de transition présent)" 1 "$(events 'apt-get install -y -q --allow-downgrades firefox$')"
assert_eq "firefox-l10n-fr installé (français)" 1 "$(events 'apt-get install -y -q firefox-l10n-fr')"
assert_ok "le paquet installé est celui de Mozilla" grep -qP '^firefox\t154' "$TEST_TMP/installed"
assert_eq "snap firefox retiré après le .deb" 1 "$(events 'snap remove firefox')"
assert_ok "snap remove vient après apt-get install firefox" bash -c "[[ \$(grep -n 'allow-downgrades firefox\$' '$EVENTS' | cut -d: -f1) -lt \$(grep -n 'snap remove' '$EVENTS' | cut -d: -f1) ]]"
assert_fail "snap firefox absent ensuite" test -f "$TEST_TMP/snap-firefox"
assert_eq "navigateur par défaut : Brave" "brave-browser.desktop" "$(cat "$TEST_TMP/default-browser")"
assert_eq "aucun dépôt ni paquet Chrome" 0 "$(events 'google-chrome')"

printf '%s\n' "== module_configure : stratégies Brave et Firefox (fr), pas Chrome =="
assert_ok "module_configure réussit (sans session op : étape manuelle)" module_configure
assert_file "stratégie Brave" "$NAV_ETC/etc/brave/policies/managed/1password.json"
assert_eq "stratégie Brave = fichier versionné" "$(cat "$DOTFILES_DIR/config/navigateur/chromium-1password.json")" "$(cat "$NAV_ETC/etc/brave/policies/managed/1password.json")"
assert_eq "stratégie Brave : normal_installed" normal_installed "$(jq -r '.ExtensionSettings.aeblfdkhhhdcdjpifhhbdiojplfjncoa.installation_mode' "$NAV_ETC/etc/brave/policies/managed/1password.json")"
assert_file "stratégie Firefox" "$NAV_ETC/etc/firefox/policies/policies.json"
assert_eq "Firefox : extension 1Password normal_installed" normal_installed "$(jq -r '.policies.ExtensionSettings["{d634138d-c276-4fc8-924b-40a0ea21d284}"].installation_mode' "$NAV_ETC/etc/firefox/policies/policies.json")"
assert_eq "Firefox : intl.locale.requested = fr (l10n-fr installé)" fr "$(jq -r '.policies.Preferences["intl.locale.requested"].Value' "$NAV_ETC/etc/firefox/policies/policies.json")"
assert_eq "Firefox : statut default (modifiable)" default "$(jq -r '.policies.Preferences["intl.locale.requested"].Status' "$NAV_ETC/etc/firefox/policies/policies.json")"
assert_fail "aucune stratégie Chrome (absent)" test -e "$NAV_ETC/etc/opt/chrome"
assert_contains "Brave Sync sans session : étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "Brave Sync"
assert_eq "aucune lecture op sans session" 0 "$(events 'op read')"

printf '%s\n' "== réexécution : rien n'est réécrit =="
n_install=$(grep -c 'install -m' "$LOG_FILE" || true)
assert_ok "module_configure réussit à nouveau" module_configure
assert_eq "aucune stratégie réécrite" "$n_install" "$(grep -c 'install -m' "$LOG_FILE" || true)"

printf '%s\n' "== relance : Brave installé précoché, Chrome ajouté, défaut déjà dans la sélection =="
: >"$EVENTS"; rm -f "$TEST_TMP/gum-multi"
export FAKE_BROWSERS='Brave\nGoogle Chrome' FAKE_DEFAULT=Firefox
assert_ok "module_install réussit" module_install
assert_contains "Brave et Firefox précochés" "$(cat "$TEST_TMP/gum-multi")" "--selected=Brave,Firefox"
assert_eq "pas de question sur le défaut (Brave déjà par défaut)" 0 "$(events 'gum Navigateur par')"
assert_eq "Brave non réinstallé" 0 "$(events 'apt-get install -y -q brave-browser')"
assert_ok "/etc/default/google-chrome écrit avant apt-get install" bash -c "grep -q 'repo_add_once=\"false\"' '$NAV_ETC/etc/default/google-chrome'"
assert_eq "google-chrome-stable installé" 1 "$(events 'apt-get install -y -q google-chrome-stable')"
assert_contains "dépôt Chrome en amd64" "$(cat "$APT_SOURCES_DIR/google-chrome.sources")" "Architectures: amd64"
assert_eq "snap firefox non touché (Firefox non choisi)" 0 "$(events 'snap')"
module_configure >/dev/null 2>&1
assert_file "stratégie Chrome écrite à la configuration" "$NAV_ETC/etc/opt/chrome/policies/managed/1password.json"
unset FAKE_BROWSERS FAKE_DEFAULT

printf '%s\n' "== sélection vide et interruption =="
: >"$EVENTS"
out=$(FAKE_BROWSERS='' module_install 2>&1); rc=$?
assert_eq "sélection vide : réussit" 0 "$rc"
assert_contains "sélection vide : rien à installer" "$out" "rien à installer"
assert_eq "sélection vide : aucun apt-get" 0 "$(events 'apt-get')"
FAKE_GUM_RC=130 module_install >/dev/null 2>&1; rc=$?
assert_eq "Ctrl-C sur la sélection → échec" 1 "$rc"

printf '%s\n' "== langue de Firefox : trois options =="
reset; export LANG=fr_CA.UTF-8
FAKE_BROWSERS=Firefox FAKE_LANG="Comme Ubuntu (fr)" module_install >/dev/null 2>&1
assert_eq "comme Ubuntu (fr_CA) → firefox-l10n-fr" 1 "$(events 'apt-get install -y -q firefox-l10n-fr')"
assert_contains "option affichée avec la langue détectée" "$(cat "$TEST_TMP/gum-args")" "Comme Ubuntu (fr)"
reset; export LANG=en_CA.UTF-8
FAKE_BROWSERS=Firefox FAKE_LANG="Comme Ubuntu (en)" module_install >/dev/null 2>&1
assert_eq "comme Ubuntu (en_CA) → aucun paquet de langue" 0 "$(events 'l10n')"
module_configure >/dev/null 2>&1
assert_eq "stratégie sans intl.locale.requested" null "$(jq -r '.policies.Preferences' "$NAV_ETC/etc/firefox/policies/policies.json")"
reset 'firefox\t154.0' 'firefox-l10n-fr\t154.0'
FAKE_BROWSERS=Firefox FAKE_LANG=Anglais module_install >/dev/null 2>&1
assert_eq "anglais avec l10n-fr présent → retiré" 1 "$(events 'apt-get remove -y -q firefox-l10n-fr')"
assert_eq "firefox (.deb Mozilla déjà là) non réinstallé" 0 "$(events 'allow-downgrades firefox$')"
module_configure >/dev/null 2>&1
assert_eq "la préférence de langue disparaît" null "$(jq -r '.policies.Preferences' "$NAV_ETC/etc/firefox/policies/policies.json")"
reset; export LANG=de_DE.UTF-8
out=$(FAKE_BROWSERS=Firefox FAKE_LANG="Comme Ubuntu (de)" module_install 2>&1)
assert_contains "autre langue : avertissement" "$out" "aucun paquet de langue"
export LANG=C.UTF-8
assert_eq "LANG=C → en" en "$(_nav_system_lang)"

printf '%s\n' "== Brave Sync : 25ᵉ mot =="
assert_eq "10 mai 2022 00:00 UTC → abandon (index 0)" abandon "$(NAV_NOW=1652140800 _nav_brave_word25)"
assert_eq "10 mai 2022 11:59 UTC → toujours abandon" abandon "$(NAV_NOW=$((1652140800 + 43199)) _nav_brave_word25)"
assert_eq "10 mai 2022 12:00 UTC → ability (bascule à midi UTC)" ability "$(NAV_NOW=$((1652140800 + 43200)) _nav_brave_word25)"
assert_eq "21 sept 2026 18:00 UTC → index 1596 (vérifié sur la note réelle)" "$(sed -n 1597p "$DOTFILES_DIR/config/navigateur/bip39-english.txt")" "$(NAV_NOW=1790013600 _nav_brave_word25)"

printf '%s\n' "== Brave Sync : parcours guidé =="
reset 'brave-browser\t1.80'; touch "$TEST_TMP/session"
seq -f 'mot%g' 1 25 | paste -sd' ' >"$TEST_TMP/note"
expected25=$(NAV_NOW=1790013600 _nav_brave_word25)
# La chaîne apparaît dans Preferences pendant l'attente (sondage à 0,1 s ; délai de 3 s :
# wait_for compte en secondes entières, 1 s pourrait expirer aussitôt).
( sleep 0.3; printf '{"brave_sync_v2":{"seed":"chiffre"}}' >"$NAV_BRAVE_PREFS" ) &
out=$(NAV_NOW=1790013600 module_configure 2>&1); rc=$?
wait
assert_eq "module_configure réussit" 0 "$rc"
assert_eq "une lecture op de la note" 1 "$(events 'op read')"
assert_eq "presse-papiers vidé après la chaîne rejointe" "" "$(cat "$TEST_TMP/clipboard")"
assert_contains "chaîne rejointe signalée" "$out" "chaîne rejointe"
assert_not_contains "aucune étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "Brave Sync"
sleep 0.3
assert_contains "Brave ouvert sur la page de sync" "$(cat "$TEST_TMP/brave.log")" "brave://settings/braveSync/setup"
assert_not_contains "la graine n'est pas dans le journal" "$(cat "$LOG_FILE")" "mot1 mot2"
assert_not_contains "la graine n'est pas à l'écran" "$out" "mot1 mot2"
# Même parcours sans que la chaîne n'arrive : contenu du presse-papiers et « Passer ».
reset 'brave-browser\t1.80'; touch "$TEST_TMP/session"
seq -f 'mot%g' 1 25 | paste -sd' ' >"$TEST_TMP/note"
out=$(NAV_NOW=1790013600 FAKE_SYNC="Passer (étape manuelle)" module_configure 2>&1); rc=$?
assert_eq "« Passer » : réussit" 0 "$rc"
assert_eq "phrase = 24 mots de graine + mot du jour (le 25ᵉ de la note ignoré)" "$(seq -f 'mot%g' 1 24 | paste -sd' ') $expected25" "$(cat "$TEST_TMP/clipboard")"
assert_contains "« Passer » : étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "Brave Sync"
# Chaîne déjà rejointe : rien.
reset 'brave-browser\t1.80'; touch "$TEST_TMP/session"; printf '{"brave_sync_v2":{"seed":"x"}}' >"$NAV_BRAVE_PREFS"
out=$(module_configure 2>&1)
assert_eq "déjà synchronisé : aucune lecture op" 0 "$(events 'op read')"
assert_contains "déjà synchronisé : signalé" "$out" "déjà rejointe"
assert_fail "déjà synchronisé : Brave non ouvert" test -f "$TEST_TMP/brave.log"
# Note absente ou mal formée.
reset 'brave-browser\t1.80'; touch "$TEST_TMP/session"
out=$(module_configure 2>&1); rc=$?
assert_eq "note absente : réussit" 0 "$rc"
assert_contains "note absente : avertissement" "$out" "impossible"
assert_contains "note absente : étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "Brave Sync"
reset 'brave-browser\t1.80'; touch "$TEST_TMP/session"; printf 'seulement trois mots\n' >"$TEST_TMP/note"
out=$(module_configure 2>&1)
assert_contains "note trop courte : avertissement" "$out" "24 mots"
# Sans Brave : rien du tout.
reset 'firefox\t154.0'; touch "$TEST_TMP/session"
module_configure >/dev/null 2>&1
assert_eq "sans Brave : aucune lecture op" 0 "$(events 'op read')"

test_done
