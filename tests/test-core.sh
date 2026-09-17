#!/usr/bin/env bash
# tests/test-core.sh — lib/core.sh : journal, messages, run/run_sudo, has_gui, garde-fous.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

printf '%s\n' "== Journal =="
assert_file "le journal est créé au chargement" "$LOG_FILE"
log_info "message de test" 2>/dev/null
assert_contains "log_info écrit dans le journal" "$(cat "$LOG_FILE")" "INFO  message de test"
screen=$(log_warn "attention" 2>&1 >/dev/null)
assert_contains "log_warn écrit à l'écran (stderr)" "$screen" "attention"
assert_eq "log_* n'écrit rien sur stdout" "" "$(log_ok "ok" 2>/dev/null)"

printf '%s\n' "== run =="
assert_ok "run true renvoie 0" run true
assert_rc "run propage le code de sortie" 3 run sh -c 'echo sortie-capturee >&2; exit 3'
assert_contains "run journalise la commande" "$(cat "$LOG_FILE")" '$ sh -c echo sortie-capturee'
assert_contains "run journalise la sortie (stderr inclus)" "$(cat "$LOG_FILE")" "sortie-capturee"
screen=$(run sh -c 'exit 7' 2>&1)
assert_contains "run affiche le code en cas d'échec" "$screen" "Échec (code 7)"
assert_contains "run affiche le chemin du journal en cas d'échec" "$screen" "$LOG_FILE"
assert_eq "run n'affiche rien à l'écran en cas de succès" "" "$(run printf '%s\n' bonjour 2>&1)"
assert_contains "la sortie de run va dans le journal, pas à l'écran" "$(cat "$LOG_FILE")" "bonjour"
assert_fail "run ferme stdin (pas de question possible)" run sh -c 'read -r x'
_UI_SPINNING=1 screen=$(run false 2>&1)
assert_eq "sous ui_spin, run laisse l'affichage de l'échec au spinner" "" "$screen"

printf '%s\n' "== run_sudo =="
# shellcheck disable=SC2329  # doublure de sudo, invoquée indirectement par run_sudo
sudo() { printf 'sudo %s\n' "$*"; }
run_sudo whoami
unset -f sudo
assert_contains "run_sudo passe par sudo -n" "$(cat "$LOG_FILE")" "sudo -n whoami"

printf '%s\n' "== has_gui =="
assert_fail "faux dans WSL même avec DISPLAY (WSLg)" env WSL_DISTRO_NAME=Ubuntu DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 bash -c 'source lib/core.sh; has_gui'
_gui() { env -u WSL_DISTRO_NAME -u DISPLAY -u WAYLAND_DISPLAY -u XDG_SESSION_TYPE "$@" bash -c "LOG_FILE=$LOG_FILE; source lib/core.sh; has_gui"; }
assert_ok   "vrai avec XDG_SESSION_TYPE=wayland" _gui env XDG_SESSION_TYPE=wayland
assert_ok   "vrai avec XDG_SESSION_TYPE=x11"     _gui env XDG_SESSION_TYPE=x11
assert_ok   "vrai avec DISPLAY seul (hors WSL)"  _gui env DISPLAY=:1
assert_fail "faux sans aucune variable (TTY, SSH)" _gui env XDG_SESSION_TYPE=tty
if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
  assert_fail "faux dans cette WSL de développement" has_gui
fi

printf '%s\n' "== Garde-fous =="
assert_ok "require_not_root passe pour un utilisateur normal" require_not_root
assert_rc "die sort avec le code 1" 1 bash -c "LOG_FILE=$LOG_FILE; source lib/core.sh; die 'fatal'"
assert_contains "die journalise le message" "$(cat "$LOG_FILE")" "ERROR fatal"
out=$(bash -c "LOG_FILE=$LOG_FILE; source lib/core.sh; add_cleanup 'echo nettoyage-fait'; exit 0")
assert_eq "add_cleanup s'exécute à la sortie" "nettoyage-fait" "$out"
out=$(bash -c "LOG_FILE=$LOG_FILE; source lib/core.sh; add_cleanup 'echo nettoyage-sous-shell'; ( true ); echo fin")
assert_eq "le nettoyage ne se déclenche pas à la sortie d'un sous-shell" $'fin\nnettoyage-sous-shell' "$out"

test_done
