#!/usr/bin/env bash
# tests/test-fonts.sh — lib/fonts.sh hors ligne et sans sudo : fc-list et
# fc-cache sont doublés (fc-list lit la liste des familles dans un fichier, que
# fc-cache met à jour comme le ferait un vrai rafraîchissement), FONTS_DIR pointe
# dans le dossier temporaire et les archives sont servies en file://.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
FONTS_DIR="$TEST_TMP/fonts"
# shellcheck source=../lib/fonts.sh
source "$DOTFILES_DIR/lib/fonts.sh"

# --- doublures fontconfig ---------------------------------------------------------
export FAKE_DIR="$TEST_TMP"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
FAMILIES="$TEST_TMP/families"; : >"$FAMILIES"
NEXT="$TEST_TMP/families-next"; : >"$NEXT"
mkdir -p "$TEST_TMP/bin"
cat >"$TEST_TMP/bin/fc-list" <<'FAKE'
#!/usr/bin/env bash
cat "$FAKE_DIR/families" 2>/dev/null
FAKE
# fc-cache : journalise l'appel et publie les familles que le prochain
# rafraîchissement doit faire apparaître (vide = la police reste inconnue).
cat >"$TEST_TMP/bin/fc-cache" <<'FAKE'
#!/usr/bin/env bash
printf 'fc-cache %s\n' "$*" >>"$FAKE_DIR/calls"
cp -f "$FAKE_DIR/families-next" "$FAKE_DIR/families"
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
count_calls() { grep -c -- "$1" "$CALLS" || true; }

# --- archives de test --------------------------------------------------------------
SRC="$TEST_TMP/src"
mkdir -p "$SRC"
printf 'fausse police\n' >"$SRC/PoliceTest-Regular.ttf"
printf 'fausse police\n' >"$SRC/PoliceTest-Bold.otf"
printf 'licence\n' >"$SRC/LICENSE.txt"
( cd "$TEST_TMP" && python3 -m zipfile -c "$TEST_TMP/police.zip" src/ )
ZIP_URL="file://$TEST_TMP/police.zip"
mkdir -p "$TEST_TMP/vide"
printf 'que du texte\n' >"$TEST_TMP/vide/LISEZMOI.txt"
( cd "$TEST_TMP" && python3 -m zipfile -c "$TEST_TMP/sans-police.zip" vide/ )
printf 'pas une archive\n' >"$TEST_TMP/casse.zip"

printf '%s\n' "== font_installed =="
assert_fail "famille inconnue" font_installed "Police Test"
printf 'Police Test\n' >"$FAMILIES"
assert_ok "famille connue de fontconfig" font_installed "Police Test"
assert_fail "correspondance exacte : un préfixe ne suffit pas" font_installed "Police"
printf 'Police Test Mono\n' >"$FAMILIES"
assert_fail "…ni une famille plus longue" font_installed "Police Test"
printf 'Autre Police,Police Test\n' >"$FAMILIES"
assert_ok "alias séparés par des virgules" font_installed "Police Test"
printf 'Police\\-Test\n' >"$FAMILIES"
assert_ok "caractère échappé par fontconfig" font_installed "Police-Test"
printf 'Police Test\n' >"$FAMILIES"

printf '%s\n' "== police déjà installée =="
: >"$CALLS"
assert_ok "réussit sans rien faire" install_font "Police Test" PoliceTest "$ZIP_URL"
assert_eq "aucun rafraîchissement du cache" 0 "$(count_calls 'fc-cache')"
assert_fail "aucun dossier de police créé" test -e "$FONTS_DIR/PoliceTest"

printf '%s\n' "== première installation =="
: >"$CALLS"; : >"$FAMILIES"
printf 'Police Test\n' >"$NEXT"
assert_ok "réussit" install_font "Police Test" PoliceTest "$ZIP_URL"
assert_file ".ttf copié" "$FONTS_DIR/PoliceTest/PoliceTest-Regular.ttf"
assert_file ".otf copié" "$FONTS_DIR/PoliceTest/PoliceTest-Bold.otf"
assert_fail "les fichiers hors police ne sont pas copiés" test -e "$FONTS_DIR/PoliceTest/LICENSE.txt"
assert_eq "cache rafraîchi une fois, sur FONTS_DIR" 1 "$(count_calls "fc-cache -f $FONTS_DIR")"
assert_ok "la famille est ensuite connue" font_installed "Police Test"
assert_ok "copié dans le dossier demandé" test -d "$FONTS_DIR/PoliceTest"

printf '%s\n' "== dossier explicite =="
: >"$FAMILIES"
assert_ok "réussit" install_font "Police Test" MonDossier "$ZIP_URL"
assert_file "copié dans le dossier demandé" "$FONTS_DIR/MonDossier/PoliceTest-Regular.ttf"

printf '%s\n' "== échecs : aucun dossier laissé =="
: >"$CALLS"; : >"$FAMILIES"
assert_fail "URL injoignable → échec" install_font "Autre Police" AutrePolice "file://$TEST_TMP/nexiste-pas.zip"
assert_fail "aucun dossier de police" test -e "$FONTS_DIR/AutrePolice"
out=$(install_font "Autre Police" AutrePolice "file://$TEST_TMP/casse.zip" 2>&1)
assert_contains "archive illisible → l'erreur nomme l'URL" "$out" "casse.zip"
assert_fail "aucun dossier de police" test -e "$FONTS_DIR/AutrePolice"
out=$(install_font "Autre Police" AutrePolice "file://$TEST_TMP/sans-police.zip" 2>&1)
assert_contains "archive sans .ttf ni .otf → l'erreur nomme l'URL" "$out" "sans-police.zip"
assert_fail "aucun dossier de police" test -e "$FONTS_DIR/AutrePolice"
assert_eq "aucun rafraîchissement du cache dans ces trois cas" 0 "$(count_calls 'fc-cache')"

printf '%s\n' "== famille absente après rafraîchissement =="
: >"$FAMILIES"; : >"$NEXT"
out=$(install_font "Famille Inexistante" FamilleInexistante "$ZIP_URL" 2>&1)
assert_contains "échec en nommant la famille" "$out" "Famille Inexistante"
assert_fail "le dossier créé est retiré" test -e "$FONTS_DIR/FamilleInexistante"
# Dossier préexistant : seuls les fichiers copiés par ce helper sont retirés,
# la police déjà en place y reste.
mkdir -p "$FONTS_DIR/DossierPartage"
printf 'autre police\n' >"$FONTS_DIR/DossierPartage/AutrePolice-Regular.ttf"
assert_fail "dossier préexistant → échec" install_font "Famille Inexistante" DossierPartage "$ZIP_URL"
assert_fail "les fichiers copiés sont retirés" test -e "$FONTS_DIR/DossierPartage/PoliceTest-Regular.ttf"
assert_file "la police déjà présente est conservée" "$FONTS_DIR/DossierPartage/AutrePolice-Regular.ttf"

printf '%s\n' "== arguments =="
assert_fail "famille seule → échec" install_font "Police Test"
assert_fail "sans URL → échec" install_font "Police Test" PoliceTest
assert_fail "famille vide → échec" install_font "" PoliceTest "$ZIP_URL"

printf '%s\n' "== fichiers de police servis directement =="
# Cas des quatre .ttf publiés par Powerlevel10k : des fichiers, pas une archive,
# et un nom d'URL encodé (%20) que le helper décode pour rester lisible.
: >"$CALLS"; : >"$FAMILIES"
printf 'Police Fichier\n' >"$NEXT"
# Sur disque, de vrais espaces ; dans l'URL, des %20 — exactement ce que sert
# GitHub pour « MesloLGS NF Regular.ttf ». curl décode, le helper aussi.
cp "$SRC/PoliceTest-Regular.ttf" "$TEST_TMP/Police Fichier Regular.ttf"
cp "$SRC/PoliceTest-Bold.otf" "$TEST_TMP/Police Fichier Bold.otf"
assert_ok "plusieurs URL de fichiers" install_font "Police Fichier" PoliceFichier \
  "file://$TEST_TMP/Police%20Fichier%20Regular.ttf" "file://$TEST_TMP/Police%20Fichier%20Bold.otf"
assert_file "nom de fichier décodé" "$FONTS_DIR/PoliceFichier/Police Fichier Regular.ttf"
assert_file ".otf installé aussi" "$FONTS_DIR/PoliceFichier/Police Fichier Bold.otf"
assert_eq "cache rafraîchi une fois" 1 "$(count_calls "fc-cache -f $FONTS_DIR")"

: >"$CALLS"; : >"$FAMILIES"
out=$(install_font "Police Absente" PoliceAbsente \
  "file://$TEST_TMP/Police%20Fichier%20Regular.ttf" "file://$TEST_TMP/nexiste-pas.ttf" 2>&1)
assert_contains "une URL manquante → l'erreur la nomme" "$out" "nexiste-pas.ttf"
assert_fail "aucun dossier de police laissé" test -e "$FONTS_DIR/PoliceAbsente"
assert_eq "aucun rafraîchissement du cache" 0 "$(count_calls 'fc-cache')"

: >"$FAMILIES"
out=$(install_font "Police Bizarre" PoliceBizarre "file://$TEST_TMP/police.tar.gz" 2>&1)
assert_contains "extension non reconnue → l'erreur la nomme" "$out" "police.tar.gz"
assert_fail "aucun dossier de police laissé" test -e "$FONTS_DIR/PoliceBizarre"

test_done
