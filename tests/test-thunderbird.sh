#!/usr/bin/env bash
# tests/test-thunderbird.sh — module thunderbird avec un HOME et une racine /etc
# isolés, et des archives .tar.xz fabriquées sur place, une par langue (un faux
# thunderbird/thunderbird qui répond à --version, une icône, un omni.ja qui porte
# res/multilocale.txt), servies en file:// par THUNDERBIRD_URL (@LANG@ remplacé).
# Un faux `curl` compte les téléchargements puis passe la main au vrai ; la
# doublure run_sudo note chaque appel et exécute sans sudo (écritures sous la
# racine isolée), ou échoue sur demande. Les fonctions du module sont appelées
# par module_call, chacune dans son sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

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
assert_contains "étape : comptes et agendas" "$(cat "$MANUAL_STEPS_FILE")" "comptes de courriel et les agendas Google"
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

test_done
