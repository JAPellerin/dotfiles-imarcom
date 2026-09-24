#!/usr/bin/env bash
# tests/test-thunderbird.sh — module thunderbird avec un HOME isolé et une archive
# .tar.xz fabriquée sur place (un faux thunderbird/thunderbird qui répond à
# --version, une icône), servie en file:// par THUNDERBIRD_URL. Un faux `curl`
# compte les téléchargements puis passe la main au vrai ; un faux `sudo` note
# tout appel. Les fonctions du module sont appelées par module_call, chacune dans
# son sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

export HOME="$TEST_TMP/home" TMPDIR="$TEST_TMP/tmp" FAKE_DIR="$TEST_TMP"
mkdir -p "$HOME" "$TMPDIR" "$TEST_TMP/bin"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
MOD="$DOTFILES_DIR/modules/62-thunderbird.sh"
INSTALL_DIR="$HOME/.local/share/thunderbird"
BIN="$HOME/.local/bin/thunderbird"
DESKTOP="$HOME/.local/share/applications/thunderbird.desktop"
REAL_CURL=$(command -v curl)

cat >"$TEST_TMP/bin/curl" <<FAKE
#!/usr/bin/env bash
printf 'curl %s\n' "\$*" >>"\$FAKE_DIR/calls"
exec "$REAL_CURL" "\$@"
FAKE
cat >"$TEST_TMP/bin/sudo" <<'FAKE'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$FAKE_DIR/sudo-calls"
exit 1
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Archive comme celle de Mozilla : un dossier thunderbird/ à la racine.
mkdir -p "$TEST_TMP/src/thunderbird/chrome/icons/default"
printf '#!/bin/sh\necho "Mozilla Thunderbird 156.0.1"\n' >"$TEST_TMP/src/thunderbird/thunderbird"
chmod +x "$TEST_TMP/src/thunderbird/thunderbird"
printf 'png' >"$TEST_TMP/src/thunderbird/chrome/icons/default/default128.png"
tar -cJf "$TEST_TMP/thunderbird.tar.xz" -C "$TEST_TMP/src" thunderbird
export THUNDERBIRD_URL="file://$TEST_TMP/thunderbird.tar.xz"

mcall() { module_call "$MOD" "$1"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }
leftovers() { find "$HOME/.local/share" "$TMPDIR" -maxdepth 1 -name '*thunderbird.*' 2>/dev/null; }
reset_install() { rm -rf "$INSTALL_DIR" "$BIN" "$DESKTOP"; : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; }

printf '%s\n' "== état initial =="
assert_rc "module_check → 1 (à faire)" 1 mcall module_check

printf '%s\n' "== première application =="
assert_ok "module_install réussit" mcall module_install
assert_ok "module_configure réussit" mcall module_configure
assert_eq "un téléchargement, depuis THUNDERBIRD_URL" "1 1" "$(count_calls '^curl ') $(count_calls "$THUNDERBIRD_URL")"
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
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
assert_ok "module_install réussit" mcall module_install
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucun téléchargement" 0 "$(count_calls '^curl ')"
assert_eq "installation existante intacte" "$SUMS" "$(find "$INSTALL_DIR" -type f -exec cksum {} + | sort)"
assert_eq "étape des comptes non redéclarée" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_rc "module_check → 0" 0 mcall module_check

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
assert_eq "aucun sudo appelé" "" "$(cat "$TEST_TMP/sudo-calls" 2>/dev/null)"

test_done
