#!/usr/bin/env bash
# tests/test-connexion.sh — lib/connexion.sh (guided_login, open_detached) avec
# des doublures : op (session et lectures lues dans des fichiers), wl-copy
# (presse-papiers dans un fichier, refus sur demande), une application factice
# qui écrit sur ses sorties ; apt_install, ui_choose et has_gui en fonctions.
# Chaque parcours tourne dans un sous-shell au premier plan avec cleanup_scope,
# comme sous module_call. Hors ligne, sans sudo.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
export MANUAL_STEPS_FILE="$TEST_TMP/manual" OP_SESSION_FILE="$TEST_TMP/op-session"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
# shellcheck source=../lib/connexion.sh
source "$DOTFILES_DIR/lib/connexion.sh"

export FAKE_DIR="$TEST_TMP" CONNEXION_WAIT_SECONDS=2 CONNEXION_WAIT_INTERVAL=0.1
EVENTS="$TEST_TMP/events"; CLIP="$TEST_TMP/clipboard"; CONNECTED="$TEST_TMP/connected"
SECRET="S3cr3t-mdp-9f2"; USER_NAME="jpellerin"
mkdir -p "$TEST_TMP/bin"

# op : session si $FAKE_DIR/session ; lectures selon la référence, tracées.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read) printf 'op read %s\n' "${*: -1}" >>"$FAKE_DIR/events"
        case ${*: -1} in
          op://Test/App/password) printf 'S3cr3t-mdp-9f2' ;;
          op://Test/App/username) printf 'jpellerin' ;;
          *) echo "[ERROR] item introuvable" >&2; exit 1 ;;
        esac ;;
esac
FAKE
# wl-copy : presse-papiers dans un fichier ; refus si $FAKE_DIR/wlcopy-refuse.
cat >"$TEST_TMP/bin/wl-copy" <<'FAKE'
#!/usr/bin/env bash
[[ -e $FAKE_DIR/wlcopy-refuse && ${1:-} != --clear ]] && exit 1
if [[ ${1:-} == --clear ]]; then : >"$FAKE_DIR/clipboard"; else cat >"$FAKE_DIR/clipboard"; fi
FAKE
# fakeapp : trace son lancement, écrit sur ses deux sorties (ne doit rien laisser au journal).
cat >"$TEST_TMP/bin/fakeapp" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_DIR/app.log"
echo "sortie-app-stdout"; echo "sortie-app-stderr" >&2
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublures en fonctions (héritées par les sous-shells).
has_gui() { [[ ! -e $TEST_TMP/nogui ]]; }
apt_install() {
  printf 'apt_install %s\n' "$*" >>"$EVENTS"
  [[ -e $TEST_TMP/apt-refuse ]] && return 1
  [[ -n ${WL_DIR:-} ]] && cp "$TEST_TMP/bin/wl-copy" "$WL_DIR/wl-copy"
  return 0
}
# ui_choose : réponse de FAKE_CHOICE ; « Continuer » simule une connexion faite
# ensuite (le fichier de la sonde apparaît), pour un résultat déterministe.
ui_choose() {
  printf 'choose\n' >>"$EVENTS"
  local choice=${FAKE_CHOICE:-Passer (étape manuelle)}
  [[ $choice == Continuer* ]] && touch "$CONNECTED"
  printf '%s\n' "$choice"
}
probe() { [[ -e $CONNECTED ]]; }
# Sonde qui interrompt son propre sous-shell (SIGINT) au deuxième appel.
probe_interrupt() {
  printf 'x' >>"$TEST_TMP/probe-calls"
  [[ $(wc -c <"$TEST_TMP/probe-calls") -ge 2 ]] && kill -INT "$BASHPID"
  return 1
}
secret_fn_ok() { printf 'code-calcule-42'; }
secret_fn_ko() { log_warn "Test : secret impossible à produire."; return 1; }

reset() {
  : >"$EVENTS"; : >"$MANUAL_STEPS_FILE"
  rm -f "$CLIP" "$CONNECTED" "$TEST_TMP"/{session,nogui,apt-refuse,wlcopy-refuse,app.log,probe-calls,snapshot}
  touch "$TEST_TMP/session"; : >"$LOG_FILE"
}
events() { grep -c -- "$1" "$EVENTS" || true; }
# gl <arguments de guided_login…> : un parcours dans un sous-shell au premier plan.
gl() { ( cleanup_scope; guided_login "$@" ); }
STD=(--secret op://Test/App/password --user op://Test/App/username --open open_detached fakeapp --login ";" -- "Se connecter" "Coller le mot de passe")

printf '%s\n' "== déjà connecté =="
reset; touch "$CONNECTED"
out=$(gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
assert_eq "retour 0" 0 "$rc"
assert_contains "signalé" "$out" "App : déjà fait"
assert_eq "aucune lecture 1Password" 0 "$(events 'op read')"
assert_eq "aucune installation" 0 "$(events apt_install)"
sleep 0.2
assert_fail "application non ouverte" test -e "$TEST_TMP/app.log"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== connexion faite pendant l'attente =="
reset
( sleep 0.3; cp "$CLIP" "$TEST_TMP/snapshot"; touch "$CONNECTED" ) &
out=$(gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
wait
assert_eq "retour 0" 0 "$rc"
assert_eq "mot de passe dans le presse-papiers pendant l'attente" "$SECRET" "$(cat "$TEST_TMP/snapshot")"
assert_eq "presse-papiers vidé ensuite" "" "$(cat "$CLIP")"
assert_contains "fait, signalé" "$out" "App : fait (presse-papiers vidé)"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"
sleep 0.2
assert_eq "application ouverte avec ses arguments" "--login" "$(cat "$TEST_TMP/app.log")"
assert_contains "consigne numérotée" "$out" "2. Coller le mot de passe"
assert_eq "aucune question sans délai écoulé" 0 "$(events choose)"

printf '%s\n' "== secret jamais visible, identifiant affiché =="
assert_not_contains "secret absent de la sortie" "$out" "$SECRET"
assert_not_contains "secret absent du journal" "$(cat "$LOG_FILE")" "$SECRET"
assert_contains "identifiant à l'écran" "$out" "Identifiant : $USER_NAME"
assert_contains "identifiant au journal" "$(cat "$LOG_FILE")" "Identifiant : $USER_NAME"

printf '%s\n' "== délai écoulé puis « Passer » =="
reset
out=$(FAKE_CHOICE="Passer (étape manuelle)" gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
assert_eq "retour 0" 0 "$rc"
assert_eq "question posée une fois" 1 "$(events choose)"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP")"
assert_contains "étape manuelle déclarée" "$(cat "$MANUAL_STEPS_FILE")" "App : se connecter"

printf '%s\n' "== délai écoulé, « Continuer », puis connexion =="
reset
out=$(FAKE_CHOICE="Continuer d'attendre" gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
assert_eq "retour 0" 0 "$rc"
assert_eq "question posée une fois" 1 "$(events choose)"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP")"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== interruption (Ctrl-C) pendant l'attente =="
# Sous-shell au premier plan qui s'envoie SIGINT : en arrière-plan, bash lui ferait
# ignorer SIGINT et le test passerait par « Passer » sans avoir été interrompu (D7).
reset
( cleanup_scope; guided_login "App" probe_interrupt "App : se connecter" "${STD[@]}" ) >/dev/null 2>&1; rc=$?
assert_eq "interrompu (code 130)" 130 "$rc"
assert_eq "sonde appelée deux fois (interrompu pendant l'attente)" 2 "$(wc -c <"$TEST_TMP/probe-calls")"
assert_eq "presse-papiers vidé à l'interruption" "" "$(cat "$CLIP" 2>/dev/null)"
assert_eq "aucune question posée" 0 "$(events choose)"

printf '%s\n' "== sans session 1Password =="
reset; rm -f "$TEST_TMP/session"
out=$(gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
assert_eq "retour 0" 0 "$rc"
assert_contains "avertissement" "$out" "aucune session 1Password"
assert_contains "étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "App : se connecter"
assert_eq "aucune lecture" 0 "$(events 'op read')"
sleep 0.2
assert_fail "aucune application ouverte" test -e "$TEST_TMP/app.log"
assert_fail "presse-papiers intact" test -e "$CLIP"

printf '%s\n' "== secret illisible =="
reset
out=$(gl "App" probe "App : se connecter" --secret op://Test/Absent/password -- "x" 2>&1); rc=$?
assert_eq "retour 0" 0 "$rc"
assert_contains "avertissement nommant la référence" "$out" "op://Test/Absent/password"
assert_contains "étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "App : se connecter"

printf '%s\n' "== --secret-fn =="
reset
( sleep 0.3; cp "$CLIP" "$TEST_TMP/snapshot"; touch "$CONNECTED" ) &
out=$(gl "App" probe "App : se connecter" --secret-fn secret_fn_ok -- "x" 2>&1); rc=$?
wait
assert_eq "retour 0" 0 "$rc"
assert_eq "valeur de la fonction copiée" "code-calcule-42" "$(cat "$TEST_TMP/snapshot")"
assert_eq "presse-papiers vidé" "" "$(cat "$CLIP")"
assert_not_contains "valeur absente de la sortie" "$out" "code-calcule-42"
reset
out=$(gl "App" probe "App : se connecter" --secret-fn secret_fn_ko -- "x" 2>&1); rc=$?
assert_eq "fonction en échec : retour 0" 0 "$rc"
assert_contains "fonction en échec : son avertissement" "$out" "secret impossible"
assert_contains "fonction en échec : étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "App : se connecter"
assert_fail "fonction en échec : presse-papiers intact" test -e "$CLIP"

printf '%s\n' "== presse-papiers en échec =="
reset; touch "$TEST_TMP/wlcopy-refuse"
out=$(gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
assert_eq "retour 0" 0 "$rc"
assert_contains "avertissement" "$out" "presse-papiers indisponible"
assert_contains "étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "App : se connecter"
sleep 0.2
assert_fail "aucune application ouverte" test -e "$TEST_TMP/app.log"

printf '%s\n' "== sans session graphique =="
reset; touch "$TEST_TMP/nogui"
out=$(gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
assert_eq "retour 0" 0 "$rc"
assert_contains "avertissement" "$out" "pas de session graphique"
assert_contains "étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "App : se connecter"
assert_eq "aucune lecture" 0 "$(events 'op read')"

printf '%s\n' "== wl-copy absent =="
# PATH minimal construit ici (pas celui de la machine) : le cas ne dépend pas de
# la présence d'un vrai wl-copy sur le poste qui lance les tests.
mkdir -p "$TEST_TMP/min" "$TEST_TMP/nowl"
for t in bash env cat cp date grep mkdir rm sed setsid sleep touch wc mktemp; do
  ln -sf "$(command -v "$t")" "$TEST_TMP/min/$t"
done
cp "$TEST_TMP/bin/op" "$TEST_TMP/bin/fakeapp" "$TEST_TMP/nowl/"
reset
( sleep 0.3; touch "$CONNECTED" ) &
out=$(PATH="$TEST_TMP/nowl:$TEST_TMP/min" WL_DIR="$TEST_TMP/nowl" gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
wait
assert_eq "retour 0" 0 "$rc"
assert_eq "wl-clipboard installé une fois" 1 "$(events 'apt_install wl-clipboard')"
assert_eq "puis presse-papiers vidé" "" "$(cat "$CLIP")"
rm -f "$TEST_TMP/nowl/wl-copy"
reset; touch "$TEST_TMP/apt-refuse"
out=$(PATH="$TEST_TMP/nowl:$TEST_TMP/min" gl "App" probe "App : se connecter" "${STD[@]}" 2>&1); rc=$?
assert_eq "installation en échec : retour 0" 0 "$rc"
assert_contains "installation en échec : avertissement" "$out" "wl-clipboard impossible"
assert_contains "installation en échec : étape manuelle" "$(cat "$MANUAL_STEPS_FILE")" "App : se connecter"

printf '%s\n' "== identifiant illisible =="
reset
( sleep 0.3; touch "$CONNECTED" ) &
out=$(gl "App" probe "App : se connecter" --user op://Test/Absent/username -- "x" 2>&1); rc=$?
wait
assert_eq "retour 0" 0 "$rc"
assert_contains "avertissement" "$out" "identifiant « op://Test/Absent/username » illisible"
assert_eq "le parcours continue : aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== arguments invalides =="
assert_rc "moins de trois arguments" 1 guided_login "App" probe
assert_rc "--secret et --secret-fn" 1 guided_login "App" probe "m" --secret op://a/b/c --secret-fn secret_fn_ok
assert_rc "--open sans « ; »" 1 guided_login "App" probe "m" --open fakeapp
assert_rc "option inconnue" 1 guided_login "App" probe "m" --autre

printf '%s\n' "== open_detached =="
: >"$LOG_FILE"; rm -f "$TEST_TMP/app.log"
out=$(open_detached fakeapp a b 2>&1); rc=$?
sleep 0.3
assert_eq "retour 0" 0 "$rc"
assert_eq "application lancée avec ses arguments" "a b" "$(cat "$TEST_TMP/app.log")"
assert_contains "commande tracée au journal" "$(cat "$LOG_FILE")" '$ fakeapp a b (détaché)'
assert_not_contains "sortie de l'application absente du journal" "$(cat "$LOG_FILE")" "sortie-app"
assert_not_contains "sortie de l'application absente de l'écran" "$out" "sortie-app"
out=$(open_detached application-introuvable 2>&1); rc=$?
assert_eq "introuvable : retour 0" 0 "$rc"
assert_contains "introuvable : avertissement" "$out" "Impossible de lancer application-introuvable"
assert_rc "sans commande : erreur" 1 open_detached

test_done
