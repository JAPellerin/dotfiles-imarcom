#!/usr/bin/env bash
# tests/test-module.sh — lib/module.sh avec les factices de tests/fixtures/modules/.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
MODULES_DIR="$FIXTURES_DIR/modules"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

printf '%s\n' "== module_name_from_file =="
assert_eq "préfixe NN- et .sh retirés" "1password" "$(module_name_from_file modules/10-1password.sh)"
assert_eq "sans préfixe : inchangé" "base" "$(module_name_from_file /x/base.sh)"

printf '%s\n' "== module_meta : rejets =="
assert_fail "module sans MODULE_DESC rejeté" module_meta "$MODULES_DIR/00-sans-desc.sh"
out=$(module_meta "$MODULES_DIR/00-sans-desc.sh" 2>&1 >/dev/null)
assert_contains "le message nomme le fichier" "$out" "00-sans-desc.sh"
assert_contains "le message nomme le champ" "$out" "MODULE_DESC"
assert_fail "MODULE_NAME incohérent rejeté" module_meta "$MODULES_DIR/01-mauvais-nom.sh"
out=$(module_meta "$MODULES_DIR/01-mauvais-nom.sh" 2>&1 >/dev/null)
assert_contains "nom attendu indiqué" "$out" "attendu « mauvais-nom »"
assert_contains "groupe inconnu signalé" "$out" "MODULE_GROUP « inconnu »"
assert_contains "fonction manquante signalée" "$out" "module_configure manquante"
assert_fail "fichier inexistant rejeté" module_meta "$MODULES_DIR/99-absent.sh"

printf '%s\n' "== module_meta : module valide =="
assert_ok "module valide accepté" module_meta "$MODULES_DIR/02-valide.sh"
meta=$(module_meta "$MODULES_DIR/02-valide.sh" 2>/dev/null)
assert_eq "métadonnées sur une ligne (tab)" $'valide\tModule factice conforme\tdev\tbase,autre\t1' "$meta"
assert_eq "rien ne fuit du sous-shell" "" "${FUITE_INTERNE:-}"
assert_fail "les fonctions du module ne fuient pas" declare -F module_install

printf '%s\n' "== module_call =="
assert_rc "module_check du factice → 1 (à faire)" 1 module_call "$MODULES_DIR/02-valide.sh" module_check
assert_eq "module_install s'exécute avec ses variables" "install-valide" "$(module_call "$MODULES_DIR/02-valide.sh" module_install 2>/dev/null)"
assert_ok "module_configure déclare une étape manuelle" module_call "$MODULES_DIR/02-valide.sh" module_configure
assert_file "fichier des étapes manuelles présent" "$MANUAL_STEPS_FILE"
assert_eq "étape manuelle consignée « module<TAB>texte »" $'valide\tActiver quelque chose à la main' "$(cat "$MANUAL_STEPS_FILE")"
assert_fail "module_call propage l'échec d'une fonction" module_call "$MODULES_DIR/01-mauvais-nom.sh" module_configure

test_done
