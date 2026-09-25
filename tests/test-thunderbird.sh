#!/usr/bin/env bash
# tests/test-thunderbird.sh — module thunderbird avec un HOME et une racine /etc
# isolés, et des archives .tar.xz fabriquées sur place, une par langue (un faux
# thunderbird/thunderbird qui répond à --version, une icône, un omni.ja qui porte
# res/multilocale.txt), servies en file:// par THUNDERBIRD_URL (@LANG@ remplacé).
# Un faux `curl` compte les téléchargements puis passe la main au vrai ; la
# doublure run_sudo note chaque appel et exécute sans sudo (écritures sous la
# racine isolée), ou échoue sur demande. Compte et connexion (D8 à D14) : un
# faux Thunderbird (premier lancement sans fenêtre qui crée le profil, lancement
# normal qui écrit l'autorisation Google sur demande), un faux op (élément
# Thunderbird, mot de passe Google), wl-copy ; has_gui et ui_choose en fonctions.
# Les fonctions du module sont appelées par module_call, chacune dans son
# sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
# shellcheck source=../lib/connexion.sh
source "$DOTFILES_DIR/lib/connexion.sh"

export HOME="$TEST_TMP/home" TMPDIR="$TEST_TMP/tmp" FAKE_DIR="$TEST_TMP"
mkdir -p "$HOME" "$TMPDIR" "$TEST_TMP/bin"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
MOD="$DOTFILES_DIR/modules/62-thunderbird.sh"
INSTALL_DIR="$HOME/.local/share/thunderbird"
BIN="$HOME/.local/bin/thunderbird"
DESKTOP="$HOME/.local/share/applications/thunderbird.desktop"
export THUNDERBIRD_ETC="$TEST_TMP/racine"
POLICIES="$THUNDERBIRD_ETC/etc/thunderbird/policies/policies.json"
POLICIES_SRC="$DOTFILES_DIR/config/thunderbird/policies.json"
SUDO_CALLS="$TEST_TMP/sudo-calls"
# Profils de Thunderbird dans le dossier du test ; délais courts (D14).
export THUNDERBIRD_PROFILES="$TEST_TMP/profils"
export THUNDERBIRD_START_TIMEOUT=3 THUNDERBIRD_STOP_TIMEOUT=2 THUNDERBIRD_POLL_INTERVAL=0.1
# Attente longue par défaut pour la connexion (rend la main dès qu'elle est
# constatée) ; « Passer » la raccourcit à 1 s.
export CONNEXION_WAIT_SECONDS=10 CONNEXION_WAIT_INTERVAL=0.1
# bash avertit (« setlocale: cannot change locale ») à chaque affectation d'une
# langue non installée sur la machine de test ; seul LANG compte pour le module.
exec 2> >(grep --line-buffered -v 'warning: setlocale: ' >&2)
# Ubuntu en français du Canada : Thunderbird « fr » (pas de fr-CA chez Mozilla).
export LANG=fr_CA.UTF-8
unset LANGUAGE LC_ALL LC_MESSAGES
REAL_CURL=$(command -v curl)

cat >"$TEST_TMP/bin/curl" <<FAKE
#!/usr/bin/env bash
printf 'curl %s\n' "\$*" >>"\$FAKE_DIR/calls"
exec "$REAL_CURL" "\$@"
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublure héritée par les sous-shells de module_call.
run_sudo() {
  printf 'run_sudo %s\n' "$*" >>"$SUDO_CALLS"
  [[ -e $TEST_TMP/sudo-refuse ]] && return 1
  run "$@"
}
export -f run_sudo
export SUDO_CALLS TEST_TMP

# Archive comme celle de Mozilla : un dossier thunderbird/ à la racine ; omni.ja
# (un zip) porte res/multilocale.txt, langue de la version en premier.
# make_archive <langue> <liste de multilocale.txt> <archive>
make_archive() {
  local src="$TEST_TMP/src-$1"
  mkdir -p "$src/thunderbird/chrome/icons/default"
  printf '#!/bin/sh\necho "Mozilla Thunderbird 156.0.1"\n' >"$src/thunderbird/thunderbird"
  chmod +x "$src/thunderbird/thunderbird"
  printf 'png' >"$src/thunderbird/chrome/icons/default/default128.png"
  python3 -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z: z.writestr("res/multilocale.txt", sys.argv[2] + "\n")' \
    "$src/thunderbird/omni.ja" "$2"
  tar -cJf "$3" -C "$src" thunderbird
}
make_archive fr "fr,en-US" "$TEST_TMP/thunderbird-fr.tar.xz"
make_archive en-US "en-US" "$TEST_TMP/thunderbird-en-US.tar.xz"
# Archive servie pour en-CA mais publiée en en-US : langue différente de celle demandée.
make_archive en-CA-faux "en-US" "$TEST_TMP/thunderbird-en-CA.tar.xz"
export THUNDERBIRD_URL="file://$TEST_TMP/thunderbird-@LANG@.tar.xz"

mcall() { module_call "$MOD" "$1"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }
# Session graphique et réponse au choix « Continuer / Passer » de guided_login.
has_gui() { return 0; }
ui_choose() { printf '%s\n' "${FAKE_CHOICE:-Passer (étape manuelle)}"; }
# done_profile : profil « fait » — installs.ini, compte Gmail de travail dans
# prefs.js, autorisation Google dans logins.json. Les cas qui ne portent pas sur
# le compte l'emploient : module_configure n'écrit rien et ne lance aucun parcours.
done_profile() {
  rm -rf "$THUNDERBIRD_PROFILES"
  mkdir -p "$THUNDERBIRD_PROFILES/fait.default-release"
  printf '[AABB]\nDefault=fait.default-release\nLocked=1\n' >"$THUNDERBIRD_PROFILES/installs.ini"
  printf 'user_pref("mail.server.server1.hostname", "imap.gmail.com");\nuser_pref("mail.server.server1.userName", "jean.test@imarcom.net");\n' \
    >"$THUNDERBIRD_PROFILES/fait.default-release/prefs.js"
  printf '{"logins":[{"hostname":"oauth://accounts.google.com"}]}' >"$THUNDERBIRD_PROFILES/fait.default-release/logins.json"
}
done_profile
leftovers() { find "$HOME/.local/share" "$TMPDIR" -maxdepth 1 -name '*thunderbird.*' 2>/dev/null; }
installed_lang() { unzip -p "$INSTALL_DIR/omni.ja" res/multilocale.txt; }
policies_as_repo() { cmp -s -- "$POLICIES_SRC" "$POLICIES"; }
wanted() { module_call "$MOD" _thunderbird_wanted_lang; }
reset_install() { rm -rf "$INSTALL_DIR" "$BIN" "$DESKTOP"; : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; }

printf '%s\n' "== stratégie des dictionnaires versionnée =="
assert_ok "JSON valide" jq -e . "$POLICIES_SRC"
assert_eq "deux dictionnaires, installés d'office sans être imposés" "normal_installed normal_installed" \
  "$(jq -r '[.policies.ExtensionSettings[].installation_mode] | join(" ")' "$POLICIES_SRC")"
assert_eq "anglais (Canada)" "https://addons.thunderbird.net/thunderbird/downloads/latest/canadian-english-dictionary/latest.xpi" \
  "$(jq -r '.policies.ExtensionSettings["en-CA@dictionaries.addons.mozilla.org"].install_url' "$POLICIES_SRC")"
assert_eq "français (Dicollecte)" "https://addons.thunderbird.net/thunderbird/downloads/latest/dictionnaire-fran%C3%A7ais1/latest.xpi" \
  "$(jq -r '.policies.ExtensionSettings["fr-dicollecte@dictionaries.addons.mozilla.org"].install_url' "$POLICIES_SRC")"

printf '%s\n' "== langue d'Ubuntu → langue de Thunderbird =="
assert_eq "fr_CA.UTF-8 → fr (pas de fr-CA)" fr "$(wanted)"
assert_eq "en_CA.UTF-8 → en-CA" en-CA "$(LANG=en_CA.UTF-8 wanted)"
assert_eq "en_US.UTF-8 → en-US" en-US "$(LANG=en_US.UTF-8 wanted)"
assert_eq "pt_BR.UTF-8 → pt-BR" pt-BR "$(LANG=pt_BR.UTF-8 wanted)"
assert_eq "de_DE.UTF-8 → de" de "$(LANG=de_DE.UTF-8 wanted)"
assert_eq "ca_ES.UTF-8@valencia → ca" ca "$(LANG=ca_ES.UTF-8@valencia wanted)"
assert_eq "langue non publiée → en-US" en-US "$(LANG=xx_YY.UTF-8 wanted)"
assert_eq "C → en-US" en-US "$(LANG=C wanted)"
assert_eq "LANG vide → en-US" en-US "$(LANG='' wanted)"
assert_eq "LANGUAGE l'emporte (premier élément)" en-CA "$(LANGUAGE=en_CA:fr wanted)"
assert_eq "LANGUAGE=C ignoré" fr "$(LANGUAGE=C wanted)"
assert_eq "LC_MESSAGES l'emporte sur LANG" en-US "$(LC_MESSAGES=en_US.UTF-8 wanted)"
assert_eq "LC_ALL l'emporte sur LC_MESSAGES" de "$(LC_ALL=de_DE.UTF-8 LC_MESSAGES=en_US.UTF-8 wanted)"

printf '%s\n' "== état initial =="
assert_rc "module_check → 1 (à faire)" 1 mcall module_check

printf '%s\n' "== première application =="
assert_ok "module_install réussit" mcall module_install
assert_ok "module_configure réussit" mcall module_configure
assert_eq "un téléchargement, dans la langue d'Ubuntu" "1 1" "$(count_calls '^curl ') $(count_calls "$TEST_TMP/thunderbird-fr.tar.xz")"
assert_eq "version française installée" "fr,en-US" "$(installed_lang)"
assert_ok "stratégie des dictionnaires copiée, identique au dépôt" policies_as_repo
assert_contains "stratégie écrite par run_sudo" "$(cat "$SUDO_CALLS")" "run_sudo install -m 0644 -D -- $POLICIES_SRC $POLICIES"
assert_ok "binaire installé et exécutable" test -x "$INSTALL_DIR/thunderbird"
assert_eq "dossier d'installation à l'utilisateur" "$(id -un)" "$(stat -c %U "$INSTALL_DIR")"
assert_eq "commande liée au binaire" "$INSTALL_DIR/thunderbird" "$(readlink "$BIN")"
assert_eq "thunderbird --version répond" "Mozilla Thunderbird 156.0.1" "$("$BIN" --version)"
assert_file "lanceur déposé" "$DESKTOP"
assert_ok "lanceur : fichier, pas lien" test ! -L "$DESKTOP"
assert_contains "lanceur : Exec absolu" "$(cat "$DESKTOP")" "Exec=\"$INSTALL_DIR/thunderbird\" %u"
assert_contains "lanceur : Icon absolue" "$(cat "$DESKTOP")" "Icon=$INSTALL_DIR/chrome/icons/default/default128.png"
assert_contains "lanceur : action Compose absolue" "$(cat "$DESKTOP")" "Exec=\"$INSTALL_DIR/thunderbird\" -compose"
assert_not_contains "lanceur : aucun jeton restant" "$(cat "$DESKTOP")" "@THUNDERBIRD_DIR@"
assert_eq "lanceur : chemin rendu seulement dans Exec et Icon" 4 "$(grep -c -- "$INSTALL_DIR" "$DESKTOP")"
assert_eq "aucune étape déclarée (profil fait)" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_eq "aucun temporaire restant" "" "$(leftovers)"
assert_rc "module_check → 0 (déjà fait)" 0 mcall module_check

printf '%s\n' "== déjà installé =="
printf 'témoin\n' >"$INSTALL_DIR/témoin"
SUMS=$(find "$INSTALL_DIR" -type f -exec cksum {} + | sort)
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"; : >"$SUDO_CALLS"
assert_ok "module_install réussit" mcall module_install
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucun téléchargement" 0 "$(count_calls '^curl ')"
assert_eq "installation existante intacte" "$SUMS" "$(find "$INSTALL_DIR" -type f -exec cksum {} + | sort)"
assert_eq "étape des comptes non redéclarée" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_eq "stratégie déjà là → aucun sudo" "" "$(cat "$SUDO_CALLS")"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== stratégie des dictionnaires retirée, différente, écriture en échec =="
rm -f "$POLICIES"
assert_rc "retirée → 1" 1 mcall module_check
assert_ok "module_configure la réécrit" mcall module_configure
assert_ok "identique au dépôt" policies_as_repo
printf '{"policies": {}}\n' >"$POLICIES"
assert_rc "différente → 1" 1 mcall module_check
assert_ok "module_configure la remplace" mcall module_configure
assert_ok "identique au dépôt" policies_as_repo
rm -f "$POLICIES"; touch "$TEST_TMP/sudo-refuse"
assert_fail "écriture système en échec → module_configure échoue" mcall module_configure
assert_rc "module_check → 1" 1 mcall module_check
rm -f "$TEST_TMP/sudo-refuse"
assert_ok "après correction, module_configure réussit" mcall module_configure
assert_eq "aucun téléchargement" 0 "$(count_calls '^curl ')"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== Ubuntu passé dans une autre langue =="
mkdir -p "$HOME/.config/thunderbird"; printf 'comptes\n' >"$HOME/.config/thunderbird/profiles.ini"
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
export LANG=en_US.UTF-8
assert_rc "langue installée ≠ langue d'Ubuntu → 1" 1 mcall module_check
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_contains "réinstallation annoncée" "$out" "réinstallation"
assert_eq "archive en-US téléchargée" 1 "$(count_calls "$TEST_TMP/thunderbird-en-US.tar.xz")"
assert_eq "version anglaise installée" "en-US" "$(installed_lang)"
assert_ok "ancienne installation retirée" test ! -e "$INSTALL_DIR/témoin"
assert_eq "profil intact" "comptes" "$(cat "$HOME/.config/thunderbird/profiles.ini")"
assert_eq "aucune étape des comptes (déjà dans le profil)" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_eq "aucun temporaire restant" "" "$(leftovers)"
assert_ok "module_configure réussit" mcall module_configure
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== langue installée illisible =="
rm -f "$INSTALL_DIR/omni.ja"; : >"$CALLS"
assert_rc "omni.ja absent → 1" 1 mcall module_check
assert_ok "module_install réinstalle" mcall module_install
assert_eq "version anglaise installée" "en-US" "$(installed_lang)"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== archive dans une autre langue que celle demandée =="
: >"$CALLS"
export LANG=en_CA.UTF-8
out=$(mcall module_install 2>&1); rc=$?
assert_ok "module_install échoue" test "$rc" -ne 0
assert_contains "l'échec nomme les deux langues" "$out" "Archive de Thunderbird en « en-US » au lieu de « en-CA »"
assert_eq "installation existante conservée" "en-US" "$(installed_lang)"
assert_eq "aucun temporaire restant" "" "$(leftovers)"
export LANG=fr_CA.UTF-8
assert_ok "retour d'Ubuntu au français → réinstallation" mcall module_install
assert_eq "version française installée" "fr,en-US" "$(installed_lang)"
assert_rc "module_check → 0" 0 mcall module_check
: >"$CALLS"

printf '%s\n' "== lanceur retiré =="
rm -f "$DESKTOP"
assert_rc "module_check → 1" 1 mcall module_check
assert_ok "module_configure le rétablit" mcall module_configure
assert_file "lanceur rétabli" "$DESKTOP"
assert_eq "aucun téléchargement" 0 "$(count_calls '^curl ')"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== lanceur modifié à la main =="
sed -i 's|^Exec=.*%u$|Exec=thunderbird %u|' "$DESKTOP"
assert_rc "module_check → 1" 1 mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_contains "lanceur rétabli" "$(cat "$DESKTOP")" "Exec=\"$INSTALL_DIR/thunderbird\" %u"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== commande absente ou mal liée =="
rm -f "$BIN"
assert_rc "commande absente → 1" 1 mcall module_check
printf '#!/bin/sh\n' >"$BIN"; chmod +x "$BIN"
assert_rc "commande qui n'est pas un lien → 1" 1 mcall module_check
ln -sfn /usr/bin/true "$BIN"
assert_rc "lien vers autre chose → 1" 1 mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_eq "commande reliée au binaire" "$INSTALL_DIR/thunderbird" "$(readlink "$BIN")"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== binaire absent =="
chmod -x "$INSTALL_DIR/thunderbird"
assert_rc "binaire non exécutable → 1" 1 mcall module_check
rm -rf "$INSTALL_DIR"
assert_rc "dossier d'installation absent → 1" 1 mcall module_check

printf '%s\n' "== extraction interrompue lors d'une exécution précédente =="
reset_install
mkdir -p "$HOME/.local/share/.thunderbird.AbC123/thunderbird"
printf 'partiel\n' >"$HOME/.local/share/.thunderbird.AbC123/thunderbird/libxul.so"
assert_ok "module_install réussit" mcall module_install
assert_ok "temporaire interrompu retiré" test ! -e "$HOME/.local/share/.thunderbird.AbC123"
assert_ok "binaire installé" test -x "$INSTALL_DIR/thunderbird"
assert_eq "aucun temporaire restant" "" "$(leftovers)"

printf '%s\n' "== dossier personnel avec une espace =="
mkdir -p "$TEST_TMP/mon dossier"
sp_call() { HOME="$TEST_TMP/mon dossier" module_call "$MOD" "$1"; }
assert_ok "module_install réussit" sp_call module_install
assert_ok "module_configure réussit" sp_call module_configure
SP_DIR="$TEST_TMP/mon dossier/.local/share/thunderbird"
SP_DESKTOP="$TEST_TMP/mon dossier/.local/share/applications/thunderbird.desktop"
assert_ok "installé malgré l'espace" test -x "$SP_DIR/thunderbird"
assert_contains "Exec : chemin entre guillemets" "$(cat "$SP_DESKTOP")" "Exec=\"$SP_DIR/thunderbird\" %u"
assert_contains "Icon : chemin sans guillemets" "$(cat "$SP_DESKTOP")" "Icon=$SP_DIR/chrome/icons/default/default128.png"
assert_rc "module_check → 0" 0 sp_call module_check

printf '%s\n' "== archive injoignable =="
reset_install
out=$(THUNDERBIRD_URL="file://$TEST_TMP/absente.tar.xz" mcall module_install 2>&1); rc=$?
assert_ok "module_install échoue" test "$rc" -ne 0
assert_contains "l'échec nomme l'URL" "$out" "Téléchargement de Thunderbird impossible : file://$TEST_TMP/absente.tar.xz"
assert_ok "aucun dossier d'installation" test ! -e "$INSTALL_DIR"
assert_eq "aucun temporaire restant" "" "$(leftovers)"
assert_eq "aucune étape des comptes" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== archive illisible =="
printf 'pas une archive\n' >"$TEST_TMP/illisible.tar.xz"
out=$(THUNDERBIRD_URL="file://$TEST_TMP/illisible.tar.xz" mcall module_install 2>&1); rc=$?
assert_ok "module_install échoue" test "$rc" -ne 0
assert_contains "l'échec nomme l'extraction" "$out" "Extraction de l'archive de Thunderbird impossible"
assert_ok "aucun dossier d'installation" test ! -e "$INSTALL_DIR"
assert_eq "aucun temporaire restant" "" "$(leftovers)"

printf '%s\n' "== archive sans thunderbird/thunderbird =="
mkdir -p "$TEST_TMP/autre/firefox"; printf '#!/bin/sh\n' >"$TEST_TMP/autre/firefox/firefox"
tar -cJf "$TEST_TMP/autre.tar.xz" -C "$TEST_TMP/autre" firefox
out=$(THUNDERBIRD_URL="file://$TEST_TMP/autre.tar.xz" mcall module_install 2>&1); rc=$?
assert_ok "module_install échoue" test "$rc" -ne 0
assert_contains "l'échec nomme le binaire manquant" "$out" "sans thunderbird/thunderbird"
assert_ok "aucun dossier d'installation" test ! -e "$INSTALL_DIR"
assert_eq "aucun temporaire restant" "" "$(leftovers)"

printf '%s\n' "== sudo =="
assert_eq "sudo seulement pour la stratégie des dictionnaires" "" \
  "$(grep -v -- "$THUNDERBIRD_ETC/etc/thunderbird/policies/policies.json" "$SUDO_CALLS")"

# =====================================================================================
# Compte de travail et connexion Google (D8 à D14)
# =====================================================================================
export OP_SESSION_FILE="$TEST_TMP/op-session"
CLIP="$TEST_TMP/clipboard"
SECRET="Gw-S3cr3t-mdp"
PREFS_OF() { printf '%s/%s/prefs.js' "$THUNDERBIRD_PROFILES" "$1"; }
# Faux op : session si $FAKE_DIR/session ; lectures tracées dans calls ; message
# de op 2.39.0 pour un champ absent (relevé 0.4).
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
nf() { echo "[ERROR] 2026/09/25 12:00:00 could not read secret '$ref': item 'Imarcom/Thunderbird' does not have a field '$1'" >&2; exit 1; }
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read) ref=${*: -1}
        printf 'op read %s\n' "$ref" >>"$FAKE_DIR/calls"
        [[ -f $FAKE_DIR/session ]] || { echo "[ERROR] You are not currently signed in." >&2; exit 1; }
        case $ref in
          op://Imarcom/Thunderbird/nom) [[ -e $FAKE_DIR/tb-no-nom ]] && nf nom; printf '%s' 'Jean "JD" Test' ;;
          op://Imarcom/Thunderbird/adresse)
            [[ -e $FAKE_DIR/tb-adresse-perso ]] && { printf 'jean@gmail.com'; exit 0; }
            printf 'jean.test@imarcom.net' ;;
          op://Imarcom/Thunderbird/notesPlain)
            [[ -e $FAKE_DIR/tb-note-absente ]] && nf notesPlain
            [[ -e $FAKE_DIR/tb-note-vide ]] && exit 0
            [[ -e $FAKE_DIR/tb-note-erreur ]] && { echo "[ERROR] network error" >&2; exit 1; }
            printf '<p>--</p>\n<p>Jean "JD" @NOM@ C:\\dossier</p>\r\n<img src="data:image/png;base64,SIGNATURE-FACTICE-77">' ;;
          op://Imarcom/Thunderbird/agendas/1) printf 'Équipe;c_0123@group.calendar.google.com;#C2C2C2;ecriture;affiche' ;;
          op://Imarcom/Thunderbird/agendas/2)
            [[ -e $FAKE_DIR/tb-agenda-erreur ]] && { echo "[ERROR] network error" >&2; exit 1; }
            [[ -e $FAKE_DIR/tb-session-tombe ]] && rm -f "$FAKE_DIR/session"
            printf 'Moi;jean.test@imarcom.net;#9FE1E7;ecriture;affiche' ;;
          op://Imarcom/Thunderbird/agendas/3) printf 'Mauvais;x@y;rouge;lecture;affiche' ;;
          op://Imarcom/Thunderbird/agendas/4) printf 'Encodé;a%%40b.c;#123456;lecture;masque' ;;
          op://Imarcom/Thunderbird/agendas/5) printf 'Fériés;fr#holiday@virtual;#16A765;lecture;masque' ;;
          op://Imarcom/Thunderbird/agendas/*) nf "agendas.${ref##*/}" ;;
          "op://Imarcom/Google Workspace/password") printf 'Gw-S3cr3t-mdp' ;;
          *) echo "[ERROR] introuvable" >&2; exit 1 ;;
        esac ;;
esac
FAKE
cat >"$TEST_TMP/bin/wl-copy" <<'FAKE'
#!/usr/bin/env bash
if [[ ${1:-} == --clear ]]; then : >"$FAKE_DIR/clipboard"; else cat >"$FAKE_DIR/clipboard"; fi
FAKE
chmod +x "$TEST_TMP/bin/op" "$TEST_TMP/bin/wl-copy"
# Faux Thunderbird installé à la place du binaire de l'archive. Modes
# (fichier tb-mode) du premier lancement sans fenêtre : normal (crée le profil
# de l'installation et un profil « …default » dans profiles.ini, pose le
# verrou), rien (ne crée rien), ignore-term (ignore SIGTERM), prefs-a-l-arret
# (n'écrit prefs.js qu'en s'arrêtant). --attente : tourne jusqu'à SIGTERM (un
# Thunderbird ouvert). Sans argument (parcours guidé) : écrit l'autorisation
# Google si tb-connecte existe. Boucle de sleep courts : aucun processus
# orphelin après un arrêt forcé.
cat >"$TEST_TMP/fake-thunderbird" <<'FAKE'
#!/usr/bin/env bash
R=$THUNDERBIRD_PROFILES
case ${1:-} in
  --version) echo "Mozilla Thunderbird 156.0.1"; exit 0 ;;
  --headless)
    printf 'thunderbird --headless\n' >>"$FAKE_DIR/calls"
    mode=$(cat "$FAKE_DIR/tb-mode" 2>/dev/null)
    P="$R/abcd.default-release"
    if [[ $mode == ignore-term ]]; then trap '' TERM
    else trap '[[ $mode == prefs-a-l-arret ]] && printf "user_pref(\"app.x\", 1);\n" >"$P/prefs.js"; rm -f "$P/lock"; exit 0' TERM; fi
    if [[ $mode != rien ]]; then
      mkdir -p "$P" "$R/zzzz.default"
      printf '[General]\nStartWithLastProfile=1\n\n[Profile0]\nName=default\nIsRelative=1\nPath=zzzz.default\nDefault=1\n' >"$R/profiles.ini"
      printf '[AABBCCDD]\nDefault=abcd.default-release\nLocked=1\n' >"$R/installs.ini"
      [[ $mode == prefs-a-l-arret ]] || printf 'user_pref("app.x", 1);\n' >"$P/prefs.js"
      ln -sfn "127.0.1.1:+$$" "$P/lock"
    fi
    while :; do sleep 0.1; done ;;
  --attente) trap 'exit 0' TERM; while :; do sleep 0.1; done ;;
  *)
    printf 'thunderbird lancé\n' >>"$FAKE_DIR/calls"
    if [[ -e $FAKE_DIR/tb-connecte ]]; then
      sleep 0.3
      d=$(sed -n 's/^Default=//p' "$R/installs.ini" | head -n 1)
      printf '{"logins":[{"hostname":"oauth://accounts.google.com"}]}' >"$R/$d/logins.json"
    fi ;;
esac
FAKE
chmod +x "$TEST_TMP/fake-thunderbird"
# pref <prefs.js> <clé> : valeur décodée (chaîne JavaScript lue comme du JSON).
pref() {
  python3 - "$1" "$2" <<'PY'
import json, re, sys
val = None
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r'user_pref\("([^"]+)", (.*)\);\s*$', line)
    if m and m.group(1) == sys.argv[2]:
        val = m.group(2)
if val is not None:
    v = json.loads(val)
    sys.stdout.write(v if isinstance(v, str) else json.dumps(v))
PY
}
# cal_uuid <prefs.js> <nom> : UUID de l'agenda portant ce nom.
cal_uuid() { grep -F ".name\", \"$2\")" "$1" | sed -E 's/.*calendar\.registry\.([^.]+)\.name.*/\1/'; }
# Motif qui porte le chemin du test : il ne peut désigner que ses processus.
headless_alive() { pgrep -f -- "$INSTALL_DIR/thunderbird --headless" >/dev/null; }
# reset_tb : Thunderbird installé (binaire factice), aucun profil, session active.
reset_tb() {
  rm -rf "$THUNDERBIRD_PROFILES" "$HOME/.thunderbird"
  rm -f "$TEST_TMP"/{tb-mode,tb-connecte,tb-no-nom,tb-adresse-perso,tb-note-absente,tb-note-vide,tb-note-erreur,tb-agenda-erreur,tb-session-tombe} "$CLIP"
  touch "$TEST_TMP/session"
  : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; : >"$LOG_FILE"
}
tb_install() {
  reset_install
  mcall module_install >/dev/null 2>&1
  cp "$TEST_TMP/fake-thunderbird" "$INSTALL_DIR/thunderbird"
}
tb_install

printf '%s\n' "== dépendances =="
# shellcheck disable=SC2016  # développé par le bash lancé, pas ici
assert_eq "dépend de base, shell et 1password (lancé seul, 1password passe avant)" "base shell 1password" \
  "$(bash -c 'source "$1"; printf "%s" "$MODULE_DEPS"' _ "$MOD")"

printf '%s\n' "== premier passage : profil créé, compte écrit, connexion guidée =="
reset_tb; touch "$TEST_TMP/tb-connecte"
out=$(mcall module_configure 2>&1); rc=$?
P=$(PREFS_OF abcd.default-release)
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "premier lancement sans fenêtre" "$(cat "$CALLS")" "thunderbird --headless"
assert_fail "premier lancement arrêté" headless_alive
assert_ok "profil de l'installation (installs.ini), pas le « …default » de profiles.ini" test -f "$P"
assert_fail "rien écrit dans le profil « …default »" test -e "$(PREFS_OF zzzz.default)"
assert_eq "compte en tête, défaut" "account1" "$(pref "$P" mail.accountmanager.accounts)"
assert_eq "IMAP en OAuth2" "10" "$(pref "$P" mail.server.server1.authMethod)"
assert_eq "SMTP en OAuth2" "10" "$(pref "$P" mail.smtpserver.smtp1.authMethod)"
assert_eq "identifiant IMAP" "jean.test@imarcom.net" "$(pref "$P" mail.server.server1.userName)"
assert_eq "nom (guillemets échappés)" 'Jean "JD" Test' "$(pref "$P" mail.identity.id1.fullName)"
assert_eq "signature sous la réponse" "false" "$(pref "$P" mail.identity.id1.sig_bottom)"
assert_eq "signature HTML" "true" "$(pref "$P" mail.identity.id1.htmlSigFormat)"
assert_eq "signature rendue telle quelle (\\\", \\\\, \\n, \\r, @NOM@)" \
  "$(printf '<p>--</p>\n<p>Jean "JD" @NOM@ C:\\dossier</p>\r\n<img src="data:image/png;base64,SIGNATURE-FACTICE-77">')" \
  "$(pref "$P" mail.identity.id1.htmlSigText)"
assert_eq "dossier des envoyés Gmail" "imap://jean.test%40imarcom.net@imap.gmail.com/[Gmail]/Sent Mail" "$(pref "$P" mail.identity.id1.fcc_folder)"
assert_eq "corbeille Gmail" "[Gmail]/Trash" "$(pref "$P" mail.server.server1.trash_folder_name)"
assert_eq "aucune demande « application par défaut »" "false" "$(pref "$P" mail.shell.checkDefaultClient)"
U1=$(cal_uuid "$P" "Équipe"); U2=$(cal_uuid "$P" "Moi"); U5=$(cal_uuid "$P" "Fériés")
assert_ok "trois agendas valides écrits" test -n "$U1" -a -n "$U2" -a -n "$U5"
assert_eq "agendas mal formés sautés" "" "$(cal_uuid "$P" Mauvais)$(cal_uuid "$P" Encodé)"
assert_contains "ligne mal formée nommée" "$out" "agendas/3"
assert_contains "identifiant avec % nommé" "$out" "agendas/4"
assert_eq "ordre des agendas" "$U1 $U2 $U5" "$(pref "$P" calendar.list.sortOrder)"
assert_eq "URI : @ encodé" "https://apidata.googleusercontent.com/caldav/v2/c_0123%40group.calendar.google.com/events/" "$(pref "$P" "calendar.registry.$U1.uri")"
assert_eq "URI : # encodé" "https://apidata.googleusercontent.com/caldav/v2/fr%23holiday%40virtual/events/" "$(pref "$P" "calendar.registry.$U5.uri")"
assert_eq "agenda de l'adresse = défaut" "true" "$(pref "$P" "calendar.registry.$U2.calendar-main-default")"
assert_eq "autre agenda : pas défaut" "" "$(pref "$P" "calendar.registry.$U1.calendar-main-default")"
assert_eq "lecture seule" "true" "$(pref "$P" "calendar.registry.$U5.readOnly")"
assert_eq "masqué" "false" "$(pref "$P" "calendar.registry.$U5.calendar-main-in-composite")"
assert_contains "Thunderbird ouvert pour la connexion" "$(cat "$CALLS")" "thunderbird lancé"
assert_contains "adresse affichée" "$out" "Identifiant : jean.test@imarcom.net"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP" 2>/dev/null)"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"
for secret in "$SECRET" "SIGNATURE-FACTICE-77" "c_0123"; do
  assert_not_contains "« $secret » absent de la sortie" "$out" "$secret"
  assert_not_contains "« $secret » absent du journal" "$(cat "$LOG_FILE")" "$secret"
done
assert_contains "compte annoncé avec le nombre d'agendas" "$out" "(3 agendas)"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== relance : déjà fait =="
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_eq "Thunderbird non lancé" 0 "$(count_calls 'thunderbird')"

printf '%s\n' "== prefs.js écrit seulement à l'arrêt =="
reset_tb; printf 'prefs-a-l-arret' >"$TEST_TMP/tb-mode"; touch "$TEST_TMP/tb-connecte"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "compte écrit" "account1" "$(pref "$(PREFS_OF abcd.default-release)" mail.accountmanager.accounts)"

printf '%s\n' "== premier lancement en échec =="
reset_tb; printf 'rien' >"$TEST_TMP/tb-mode"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "aucun profil créé → échec" 1 "$rc"
assert_contains "échec nommé" "$out" "Création du profil de Thunderbird impossible"
assert_fail "processus arrêté" headless_alive
reset_tb; printf 'ignore-term' >"$TEST_TMP/tb-mode"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "SIGTERM ignoré → échec" 1 "$rc"
assert_contains "arrêt forcé nommé" "$out" "arrêt forcé"
assert_fail "processus tué" headless_alive

printf '%s\n' "== profil existant sans compte =="
reset_tb; touch "$TEST_TMP/tb-connecte"
mkdir -p "$THUNDERBIRD_PROFILES/abcd.default-release"
printf '[X]\nDefault=abcd.default-release\n' >"$THUNDERBIRD_PROFILES/installs.ini"
printf 'user_pref("app.témoin", 1);' >"$(PREFS_OF abcd.default-release)"
assert_ok "module_configure réussit" mcall module_configure
P=$(PREFS_OF abcd.default-release)
assert_eq "copie de sauvegarde" 'user_pref("app.témoin", 1);' "$(cat "$P.bak")"
assert_eq "préférences d'origine gardées" "1" "$(pref "$P" app.témoin)"
assert_eq "compte ajouté" "account1" "$(pref "$P" mail.accountmanager.accounts)"
assert_eq "aucun premier lancement" 0 "$(count_calls 'thunderbird --headless')"
assert_eq "aucun fichier temporaire" "" "$(find "$THUNDERBIRD_PROFILES" -name '.prefs.js.*')"

printf '%s\n' "== seulement les dossiers locaux =="
reset_tb; touch "$TEST_TMP/tb-connecte"
mkdir -p "$THUNDERBIRD_PROFILES/abcd.default-release"
printf '[X]\nDefault=abcd.default-release\n' >"$THUNDERBIRD_PROFILES/installs.ini"
cat >"$(PREFS_OF abcd.default-release)" <<'PREFS'
user_pref("mail.accountmanager.accounts", "account2");
user_pref("mail.account.account2.server", "server2");
user_pref("mail.account.lastKey", 4);
user_pref("mail.server.server2.type", "none");
user_pref("mail.server.server2.hostname", "Local Folders");
user_pref("mail.smtpservers", "smtp1");
user_pref("mail.smtpserver.smtp1.hostname", "smtp.ancien.example");
PREFS
assert_ok "module_configure réussit" mcall module_configure
P=$(PREFS_OF abcd.default-release)
assert_eq "compte suivant lastKey, en tête, dossiers locaux gardés" "account5,account2" "$(pref "$P" mail.accountmanager.accounts)"
assert_eq "compte par défaut" "account5" "$(pref "$P" mail.accountmanager.defaultaccount)"
assert_eq "lastKey" "5" "$(pref "$P" mail.account.lastKey)"
assert_eq "serveur suivant" "imap.gmail.com" "$(pref "$P" mail.server.server3.hostname)"
assert_eq "serveurs sortants fusionnés" "smtp2,smtp1" "$(pref "$P" mail.smtpservers)"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== autre compte : aucune lecture, rien écrit =="
for cas in perso autre; do
  reset_tb
  mkdir -p "$THUNDERBIRD_PROFILES/abcd.default-release"
  printf '[X]\nDefault=abcd.default-release\n' >"$THUNDERBIRD_PROFILES/installs.ini"
  if [[ $cas == perso ]]; then host=imap.gmail.com; user=jean@gmail.com; else host=imap.example.com; user=jean@example.com; fi
  printf 'user_pref("mail.accountmanager.accounts", "account1");\nuser_pref("mail.account.account1.server", "server1");\nuser_pref("mail.server.server1.type", "imap");\nuser_pref("mail.server.server1.hostname", "%s");\nuser_pref("mail.server.server1.userName", "%s");\n' \
    "$host" "$user" >"$(PREFS_OF abcd.default-release)"
  SUM=$(cksum <"$(PREFS_OF abcd.default-release)")
  out=$(mcall module_configure 2>&1); rc=$?
  assert_eq "$cas : module_configure réussit" 0 "$rc"
  assert_contains "$cas : étape des comptes" "$(cat "$MANUAL_STEPS_FILE")" "ajouter le compte Google de travail"
  assert_eq "$cas : aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
  assert_eq "$cas : profil intact" "$SUM" "$(cksum <"$(PREFS_OF abcd.default-release)")"
  assert_rc "$cas : module_check → 1" 1 mcall module_check
done

printf '%s\n' "== Thunderbird ouvert =="
reset_tb
mkdir -p "$THUNDERBIRD_PROFILES/abcd.default-release"
printf '[X]\nDefault=abcd.default-release\n' >"$THUNDERBIRD_PROFILES/installs.ini"
: >"$(PREFS_OF abcd.default-release)"
# Un vrai programme nommé « thunderbird » : copie de perl, exécutable autonome.
# Un script lancé par env bash s'appellerait « bash » dans /proc/<pid>/comm, et
# sleep (coreutils multi-appels) refuse de démarrer sous un autre nom.
mkdir -p "$TEST_TMP/ouvert"; cp "$(readlink -f "$(command -v perl)")" "$TEST_TMP/ouvert/thunderbird"
"$TEST_TMP/ouvert/thunderbird" -e 'sleep 60' & TBPID=$!
sleep 0.2
ln -sfn "127.0.1.1:+$TBPID" "$THUNDERBIRD_PROFILES/abcd.default-release/lock"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape : fermer et relancer" "$(cat "$MANUAL_STEPS_FILE")" "Fermer Thunderbird, puis relancer"
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_eq "profil intact" "" "$(cat "$(PREFS_OF abcd.default-release)")"
assert_rc "module_check → 1" 1 mcall module_check
kill "$TBPID" 2>/dev/null; wait "$TBPID" 2>/dev/null
: >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/tb-connecte"
assert_ok "verrou orphelin (processus mort) → compte écrit" mcall module_configure
assert_eq "compte écrit" "account1" "$(pref "$(PREFS_OF abcd.default-release)" mail.accountmanager.accounts)"
reset_tb; touch "$TEST_TMP/tb-connecte"
mkdir -p "$THUNDERBIRD_PROFILES/abcd.default-release"
printf '[X]\nDefault=abcd.default-release\n' >"$THUNDERBIRD_PROFILES/installs.ini"
ln -sfn "127.0.1.1:+$$" "$THUNDERBIRD_PROFILES/abcd.default-release/lock"
assert_ok "verrou vers un autre processus (bash) → compte écrit" mcall module_configure
assert_eq "compte écrit" "account1" "$(pref "$(PREFS_OF abcd.default-release)" mail.accountmanager.accounts)"

printf '%s\n' "== empêchements avant tout profil =="
for cas in sans-session sans-nom adresse-perso; do
  reset_tb
  case $cas in
    sans-session) rm -f "$TEST_TMP/session" ;;
    sans-nom) touch "$TEST_TMP/tb-no-nom" ;;
    adresse-perso) touch "$TEST_TMP/tb-adresse-perso" ;;
  esac
  out=$(mcall module_configure 2>&1); rc=$?
  assert_eq "$cas : module_configure réussit" 0 "$rc"
  assert_contains "$cas : étape des comptes" "$(cat "$MANUAL_STEPS_FILE")" "ajouter le compte Google de travail"
  assert_fail "$cas : aucun profil créé" test -e "$THUNDERBIRD_PROFILES"
  assert_eq "$cas : aucun premier lancement" 0 "$(count_calls 'thunderbird --headless')"
  assert_eq "$cas : aucun parcours de connexion" 0 "$(count_calls 'thunderbird lancé')"
done

printf '%s\n' "== lecture interrompue : rien d'écrit =="
for cas in tb-agenda-erreur tb-note-erreur tb-session-tombe; do
  reset_tb; touch "$TEST_TMP/$cas"
  out=$(mcall module_configure 2>&1); rc=$?
  assert_eq "$cas : module_configure réussit" 0 "$rc"
  assert_contains "$cas : étape des comptes" "$(cat "$MANUAL_STEPS_FILE")" "ajouter le compte Google de travail"
  assert_fail "$cas : aucun profil créé" test -e "$THUNDERBIRD_PROFILES"
done

printf '%s\n' "== note vide ou absente : compte sans signature =="
for cas in tb-note-vide tb-note-absente; do
  reset_tb; touch "$TEST_TMP/$cas" "$TEST_TMP/tb-connecte"
  assert_ok "$cas : module_configure réussit" mcall module_configure
  assert_eq "$cas : signature vide" "" "$(pref "$(PREFS_OF abcd.default-release)" mail.identity.id1.htmlSigText)"
  assert_eq "$cas : compte écrit" "account1" "$(pref "$(PREFS_OF abcd.default-release)" mail.accountmanager.accounts)"
done

printf '%s\n' "== connexion : passer =="
reset_tb
out=$(CONNEXION_WAIT_SECONDS=1 FAKE_CHOICE="Passer (étape manuelle)" mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape : se connecter (compte déjà là)" "$(cat "$MANUAL_STEPS_FILE")" "se connecter au compte Google de travail"
assert_not_contains "pas l'étape « ajouter le compte »" "$(cat "$MANUAL_STEPS_FILE")" "ajouter le compte"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP" 2>/dev/null)"
assert_not_contains "mot de passe absent du journal" "$(cat "$LOG_FILE")" "$SECRET"
assert_rc "compte présent, pas connecté → module_check 1" 1 mcall module_check
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/tb-connecte"
assert_ok "relance → connexion seulement" mcall module_configure
assert_eq "compte non réécrit (une seule lecture : adresse et mot de passe du parcours)" 0 "$(count_calls 'op read op://Imarcom/Thunderbird/nom')"
assert_rc "module_check → 0" 0 mcall module_check

printf '%s\n' "== profil : installs.ini, profiles.ini, racine =="
tbp() { mcall _thunderbird_profile; }
reset_tb; mkdir -p "$THUNDERBIRD_PROFILES"
printf '[P0]\nName=a\nIsRelative=1\nPath=rel.default\nDefault=1\n' >"$THUNDERBIRD_PROFILES/profiles.ini"
assert_eq "profiles.ini, IsRelative=1" "$THUNDERBIRD_PROFILES/rel.default" "$(tbp)"
printf '[P0]\nName=a\nIsRelative=0\nPath=/abs/prof\nDefault=1\n' >"$THUNDERBIRD_PROFILES/profiles.ini"
assert_eq "profiles.ini, IsRelative=0" "/abs/prof" "$(tbp)"
printf '[P0]\nName=a\nIsRelative=1\nPath=pas-defaut\n\n[P1]\nName=b\nIsRelative=1\nPath=defaut\nDefault=1\n' >"$THUNDERBIRD_PROFILES/profiles.ini"
assert_eq "profiles.ini, section Default=1" "$THUNDERBIRD_PROFILES/defaut" "$(tbp)"
printf '[X]\nDefault=/chemin/absolu\n' >"$THUNDERBIRD_PROFILES/installs.ini"
assert_eq "installs.ini, Default absolu" "/chemin/absolu" "$(tbp)"
printf '[X]\nDefault=relatif.default-release\n' >"$THUNDERBIRD_PROFILES/installs.ini"
assert_eq "installs.ini l'emporte, Default relatif" "$THUNDERBIRD_PROFILES/relatif.default-release" "$(tbp)"
printf '[X]\nDefault=a\n\n[Y]\nDefault=b\n' >"$THUNDERBIRD_PROFILES/installs.ini"
assert_rc "plusieurs installations → code 2" 2 tbp
assert_eq "…sans rien afficher" "" "$(tbp 2>&1)"
out=$(mcall module_check 2>&1); rc=$?
assert_eq "module_check → 1" 1 "$rc"
assert_eq "module_check silencieux" "" "$out"
: >"$MANUAL_STEPS_FILE"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape des comptes" "$(cat "$MANUAL_STEPS_FILE")" "ajouter le compte Google de travail"
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
rm -rf "$THUNDERBIRD_PROFILES"
assert_rc "aucun profil → code 1" 1 tbp
mkdir -p "$HOME/.thunderbird"; printf '[P0]\nIsRelative=1\nPath=ancien\nDefault=1\n' >"$HOME/.thunderbird/profiles.ini"
# shellcheck disable=SC2016  # développé par le bash lancé, pas ici
assert_eq "ancien ~/.thunderbird seul → racine historique" "$HOME/.thunderbird/ancien" \
  "$(env -u THUNDERBIRD_PROFILES XDG_CONFIG_HOME="$TEST_TMP/xdg-vide" bash -c 'source "$1"; source "$2"; _thunderbird_profile' _ "$DOTFILES_DIR/lib/core.sh" "$MOD")"
rm -rf "$HOME/.thunderbird"

printf '%s\n' "== sondes et module_check =="
done_profile
assert_rc "profil fait → module_check 0" 0 mcall module_check
rm -f "$THUNDERBIRD_PROFILES/fait.default-release/logins.json"
assert_rc "sans logins.json → 1 (pas 2)" 1 mcall module_check
printf '{"logins":[{"hostname":"imap://imap.gmail.com"}]}' >"$THUNDERBIRD_PROFILES/fait.default-release/logins.json"
assert_rc "sans autorisation Google → 1" 1 mcall module_check
done_profile
sed -i 's/jean.test@imarcom.net/jean@gmail.com/' "$THUNDERBIRD_PROFILES/fait.default-release/prefs.js"
assert_rc "Gmail hors domaine de travail → 1" 1 mcall module_check
done_profile
assert_fail "aucun processus Thunderbird restant" headless_alive

test_done
