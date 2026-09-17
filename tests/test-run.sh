#!/usr/bin/env bash
# tests/test-run.sh — setup.sh en boîte noire : exécution des factices (check →
# install → configure), isolation d'un échec, saut des dépendants, module
# graphique sans GUI, idempotence, résumé final, étapes manuelles, code de sortie.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

fake_sudo
export FIXTURE_STATE_DIR="$TEST_TMP/etat" WSL_DISTRO_NAME=test
setup() { MODULES_DIR="$FIXTURES_DIR/modules" bash "$DOTFILES_DIR/setup.sh" "$@" 2>&1; }

printf '%s\n' "== première exécution : a (et sa dépendance b) =="
out=$(setup a) && rc=0 || rc=$?
assert_eq "code de sortie 0" 0 "$rc"
assert_contains "b installé avant a" "$out" $'install b\n✔ Fait.\n\n[2/2] a'
assert_file "marqueur b posé par module_install" "$FIXTURE_STATE_DIR/b"
assert_file "marqueur a posé" "$FIXTURE_STATE_DIR/a"
assert_contains "résumé : a fait" "$out" "✔ a              fait"
assert_contains "étapes manuelles reprises dans le résumé" "$out" $'Étapes manuelles restantes\n  • [a] Redémarrer la session pour a'
assert_contains "chemin du journal affiché" "$out" "Journal : $LOG_FILE"

printf '%s\n' "== idempotence : relance de a =="
out=$(setup a) && rc=0 || rc=$?
assert_eq "code de sortie 0" 0 "$rc"
assert_not_contains "module_install n'est pas rappelé" "$out" "install a"
assert_contains "b déjà fait" "$out" "· b              déjà fait"
assert_contains "a déjà fait" "$out" "· a              déjà fait"
assert_not_contains "pas d'étape manuelle si rien n'a été fait" "$out" "Étapes manuelles"

printf '%s\n' "== échec isolé, dépendants sautés, GUI absent =="
out=$(setup --all) && rc=0 || rc=$?
assert_eq "code de sortie 1 quand un module échoue" 1 "$rc"
assert_contains "base exécuté (indépendant de l'échec)" "$out" "✔ base           fait"
assert_contains "1password exécuté" "$out" "✔ 1password      fait"
assert_contains "echec : sortie de la commande fautive dans l'extrait" "$out" "detail-echec"
assert_contains "echec marqué échoué" "$out" "✖ echec          échoué"
assert_contains "dependant sauté avec la raison" "$out" "↷ dependant      sauté (dépend de « echec »)"
assert_fail "dependant n'a pas été installé" test -f "$FIXTURE_STATE_DIR/dependant"
assert_contains "gui non disponible ici" "$out" "– gui            non disponible ici"
assert_fail "gui n'a pas été installé" test -f "$FIXTURE_STATE_DIR/gui"
assert_contains "journal indiqué en cas d'échec" "$out" "Au moins un module a échoué. Journal complet : $LOG_FILE"
assert_contains "le journal contient la sortie de la commande fautive" "$(cat "$LOG_FILE")" "detail-echec"
assert_contains "le journal contient le résumé" "$(cat "$LOG_FILE")" "RESUME dependant : saute"

printf '%s\n' "== module graphique avec GUI =="
out=$(env -u WSL_DISTRO_NAME XDG_SESSION_TYPE=wayland MODULES_DIR="$FIXTURES_DIR/modules" bash "$DOTFILES_DIR/setup.sh" gui 2>&1) && rc=0 || rc=$?
assert_eq "code de sortie 0" 0 "$rc"
assert_contains "gui installé quand une session graphique existe" "$out" "✔ gui            fait"
assert_file "marqueur gui posé" "$FIXTURE_STATE_DIR/gui"

test_done
