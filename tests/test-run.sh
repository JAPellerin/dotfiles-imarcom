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
assert_contains "résumé : b fait (aucune étape manuelle)" "$out" "✔ b              fait"
assert_contains "résumé : a à terminer (étape manuelle déclarée)" "$out" "! a              à terminer (étape manuelle)"
assert_not_contains "a n'est pas marqué fait" "$out" "✔ a              fait"
assert_contains "journal : a à terminer" "$(cat "$LOG_FILE")" "RESUME a : a-terminer"
assert_contains "journal : b fait" "$(cat "$LOG_FILE")" "RESUME b : fait"
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
assert_contains "échec après une étape manuelle : l'étape reste listée" "$out" "• [echec] Étape manuelle de echec"
assert_contains "journal : echec reste échoué" "$(cat "$LOG_FILE")" "RESUME echec : echoue"

printf '%s\n' "== dépendant d'un module à terminer =="
rm -f "$FIXTURE_STATE_DIR/a" "$FIXTURE_STATE_DIR/b"
out=$(FIXTURE_B_MANUAL=1 setup a) && rc=0 || rc=$?
assert_eq "code de sortie 0 (à terminer n'est pas un échec)" 0 "$rc"
assert_contains "b à terminer" "$out" "! b              à terminer (étape manuelle)"
assert_not_contains "a non sauté" "$out" "sauté"
assert_file "a exécuté malgré b à terminer" "$FIXTURE_STATE_DIR/a"
assert_contains "étape de b listée" "$out" "• [b] Étape manuelle de b"

printf '%s\n' "== module graphique avec GUI =="
out=$(env -u WSL_DISTRO_NAME XDG_SESSION_TYPE=wayland MODULES_DIR="$FIXTURES_DIR/modules" bash "$DOTFILES_DIR/setup.sh" gui 2>&1) && rc=0 || rc=$?
assert_eq "code de sortie 0" 0 "$rc"
assert_contains "gui installé quand une session graphique existe" "$out" "✔ gui            fait"
assert_file "marqueur gui posé" "$FIXTURE_STATE_DIR/gui"

printf '%s\n' "== menu (gum factice) : annulation, sélection vide, sélection =="
# gum choose : FAKE_GUM_RC = code de sortie (130 = Échap/Ctrl-C), FAKE_GUM_OUT = lignes choisies.
mkdir -p "$TEST_TMP/bin"
cat >"$TEST_TMP/bin/gum" <<'FAKE'
#!/usr/bin/env bash
[[ $1 == choose ]] || exit 0
[[ -n ${FAKE_GUM_OUT:-} ]] && printf '%s\n' "$FAKE_GUM_OUT"
exit "${FAKE_GUM_RC:-0}"
FAKE
chmod +x "$TEST_TMP/bin/gum"
out=$(FAKE_GUM_RC=130 setup) && rc=0 || rc=$?
assert_eq "annulation du menu → code 1" 1 "$rc"
assert_contains "annulation signalée" "$out" "Sélection annulée"
assert_not_contains "le runner ne continue pas après l'annulation" "$out" "Aucun module sélectionné"
out=$(FAKE_GUM_RC=0 setup) && rc=0 || rc=$?
assert_eq "sélection vide → code 0" 0 "$rc"
assert_contains "sélection vide signalée" "$out" "Aucun module sélectionné"
rm -f "$FIXTURE_STATE_DIR/b"
out=$(FAKE_GUM_OUT="[shell] b — Module b sans dépendance — à faire" setup) && rc=0 || rc=$?
assert_eq "sélection d'un module → code 0" 0 "$rc"
assert_contains "le module choisi s'exécute" "$out" "install b"

test_done
