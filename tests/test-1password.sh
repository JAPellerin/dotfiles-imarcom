#!/usr/bin/env bash
# tests/test-1password.sh — parcours « intégration app » du module 1password
# avec des doublures (dpkg-query, xdg-open, op, gum) et un socket factice.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 absent : test sauté (socket factice impossible).\n'
  exit 0
fi

# --- Doublures ---------------------------------------------------------------------
mkdir -p "$TEST_TMP/bin" "$TEST_TMP/home"
export FAKE_DIR="$TEST_TMP"
cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/xdg-open" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"$FAKE_DIR/xdg-open.log"
FAKE
# op : `signin` réussit (crée le marqueur de session) si FAKE_SIGNIN_OK=1, sinon
# écrit une erreur sur stderr ; `whoami` réussit si le marqueur existe.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_DIR/op.log"
case $1 in
  signin)
    if [[ ${FAKE_SIGNIN_OK:-0} == 1 ]]; then touch "$FAKE_DIR/session"; exit 0; fi
    echo "[ERROR] 2026/09/18 connecting to desktop app: authorization denied" >&2; exit 1 ;;
  whoami)
    [[ -f $FAKE_DIR/session ]] || { echo "[ERROR] no session" >&2; exit 1; }
    printf 'URL: https://my.1password.com\nEmail: test@example.com\n' ;;
esac
FAKE
cat >"$TEST_TMP/bin/gum" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_DIR/gum.log"
[[ $1 == choose ]] && printf '%s\n' "${FAKE_CHOICE:-Abandonner}"
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Environnement du module : socket, délais courts, config shell et CLI isolées.
export OP_AGENT_SOCK="$TEST_TMP/agent.sock" OP_WAIT_SECONDS=3 OP_WAIT_INTERVAL=0.1 OP_OPEN_DELAY=0
export OP_CLI_CONFIG="$TEST_TMP/op-config" SHELL_COMMON_RC="$TEST_TMP/commonrc"
# shellcheck source=../modules/10-1password.sh
source "$DOTFILES_DIR/modules/10-1password.sh"
# Le repli terminal n'est pas testé ici (interactif) : doublure qui se signale.
# shellcheck disable=SC2329  # appelée indirectement par _op_connect
op_signin_interactive() { log_info "repli-terminal"; return 1; }

make_socket() { python3 -c "import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])" "$OP_AGENT_SOCK"; }
reset() { rm -f "$OP_AGENT_SOCK" "$TEST_TMP"/{session,xdg-open.log,op.log,gum.log,op-config}; : >"$MANUAL_STEPS_FILE"; }

printf '%s\n' "== agent activé pendant l'attente, op signin réussit =="
reset
( sleep 0.5; make_socket ) &
out=$(FAKE_SIGNIN_OK=1 _op_connect 2>&1); rc=$?
wait
assert_eq "succès (code 0)" 0 "$rc"
assert_eq "les deux pages de réglages sont ouvertes, Security d'abord" $'onepassword://settings/security\nonepassword://settings/developers' "$(cat "$TEST_TMP/xdg-open.log")"
assert_contains "la consigne est affichée en une fois" "$out" "Use the SSH agent"
assert_contains "la connexion dans l'app fait partie de la consigne" "$out" "Se connecter"
assert_eq "un seul op signin" 1 "$(grep -c '^signin' "$TEST_TMP/op.log")"
assert_eq "aucune commande op pendant l'attente (whoami initial, puis signin)" $'whoami\nsignin' "$(head -2 "$TEST_TMP/op.log")"
assert_contains "session constatée" "$out" "Session 1Password active via l'application (test@example.com)"
assert_fail "aucune question posée (gum non appelé)" test -e "$TEST_TMP/gum.log"
out=$(_op_ssh_agent 2>&1)
# shellcheck disable=SC2016  # ligne littérale attendue dans le fichier
assert_contains "SSH_AUTH_SOCK écrit dans la config shell commune" "$(cat "$SHELL_COMMON_RC")" 'SSH_AUTH_SOCK="$HOME/.1password/agent.sock"'
assert_contains "agent actif signalé, nouveau terminal" "$out" "nouveau terminal"
assert_eq "aucune étape manuelle consignée" "" "$(cat "$MANUAL_STEPS_FILE")"
_op_ssh_agent >/dev/null 2>&1
assert_eq "SSH_AUTH_SOCK écrit une seule fois" 1 "$(grep -c SSH_AUTH_SOCK "$SHELL_COMMON_RC")"

printf '%s\n' "== agent présent mais op signin échoue, puis abandon =="
reset; make_socket
out=$(FAKE_CHOICE="Abandonner (les modules qui ont besoin de secrets seront sautés)" _op_connect 2>&1); rc=$?
assert_eq "échec (code 1)" 1 "$rc"
assert_contains "l'erreur de op est affichée" "$out" "authorization denied"
assert_contains "rappel des réglages" "$out" "Integrate with 1Password CLI"
assert_contains "menu de reprise proposé" "$(cat "$TEST_TMP/gum.log")" "choose"
assert_eq "op signin lancé une seule fois (pas de relance d'office)" 1 "$(grep -c '^signin' "$TEST_TMP/op.log")"
assert_contains "message d'abandon" "$out" "les modules qui ont besoin de secrets seront sautés"
assert_not_contains "pas de repli terminal sur abandon" "$out" "repli-terminal"

printf '%s\n' "== délai écoulé : vérifier maintenant sans agent =="
reset
out=$(OP_WAIT_SECONDS=0 FAKE_SIGNIN_OK=1 FAKE_CHOICE="Vérifier maintenant (op signin, même sans agent SSH)" _op_connect 2>&1); rc=$?
assert_eq "succès (code 0)" 0 "$rc"
assert_contains "délai écoulé signalé comme avertissement" "$out" "délai de 0 s écoulé"
assert_not_contains "pas de rapport d'échec pour un délai" "$out" "Échec (code"
out=$(_op_ssh_agent 2>&1)
assert_contains "agent inactif signalé en avertissement" "$out" "Agent SSH 1Password inactif"
assert_eq "toujours aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== délai écoulé : continuer d'attendre puis agent =="
reset
( sleep 0.5; make_socket ) &
out=$(OP_WAIT_SECONDS=0 FAKE_SIGNIN_OK=1 FAKE_CHOICE="Continuer d'attendre (rouvre la page Developer de l'app)" _op_connect 2>&1); rc=$?
wait
assert_eq "succès (code 0)" 0 "$rc"
assert_eq "la page Developer est rouverte à chaque tour" "onepassword://settings/developers" "$(tail -1 "$TEST_TMP/xdg-open.log")"
assert_ok "plusieurs tours d'attente ont eu lieu" test "$(grep -c choose "$TEST_TMP/gum.log")" -ge 1

printf '%s\n' "== délai écoulé : connexion en terminal =="
reset
out=$(OP_WAIT_SECONDS=0 FAKE_CHOICE="Connexion en terminal (op account add / op signin, sans l'application)" _op_connect 2>&1); rc=$?
assert_contains "le repli terminal est appelé" "$out" "repli-terminal"
assert_eq "échec propagé si le repli échoue" 1 "$rc"
assert_contains "message d'échec final" "$out" "seront sautés"

printf '%s\n' "== compte CLI résiduel =="
reset; make_socket
printf '{"accounts":[{"shorthand":"perso"}]}' >"$OP_CLI_CONFIG"
out=$(FAKE_SIGNIN_OK=1 _op_connect 2>&1)
assert_contains "avertissement op account forget" "$out" "op account forget --all"

printf '%s\n' "== xdg-open absent =="
reset; make_socket; rm "$TEST_TMP/bin/xdg-open"
out=$(FAKE_SIGNIN_OK=1 _op_connect 2>&1); rc=$?
assert_eq "l'absence de xdg-open ne fait pas échouer" 0 "$rc"
assert_contains "avertissement pour ouvrir l'app à la main" "$out" "xdg-open introuvable"

test_done
