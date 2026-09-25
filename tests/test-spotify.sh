#!/usr/bin/env bash
# tests/test-spotify.sh — module spotify avec des doublures (dpkg-query lu dans
# un fichier ; run_sudo qui journalise et simule apt-get install et la copie vers
# un /etc du dossier temporaire ; apt_add_repo qui compte). Connexion guidée
# (guided_login réel, sans secret) : commande spotify factice qui, sur demande,
# écrit des préférences « connecté » pendant qu'elle tourne ; op et wl-copy qui
# journalisent tout appel (le parcours ne doit en faire aucun) ; has_gui et
# ui_choose en fonctions. Les fonctions du module sont appelées par module_call,
# chacune dans son sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
# shellcheck source=../lib/connexion.sh
source "$DOTFILES_DIR/lib/connexion.sh"

mkdir -p "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP" SPOTIFY_ETC="$TEST_TMP/racine"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
LIST_FILE="$SPOTIFY_ETC/etc/apt/sources.list.d/spotify.list"
LIST_SRC="$DOTFILES_DIR/config/spotify/spotify.list"
MOD="$DOTFILES_DIR/modules/63-spotify.sh"
# Préférences du client : chemin exporté avant tout module_call (design D8).
export SPOTIFY_PREFS="$TEST_TMP/spotify/prefs"
# Attente longue par défaut : le parcours rend la main dès la connexion constatée,
# et une machine chargée (suite complète) ne doit pas la faire expirer ; le cas
# « Passer » la raccourcit à 1 s.
export CONNEXION_WAIT_SECONDS=10 CONNEXION_WAIT_INTERVAL=0.1
REPO_CALL="apt_add_repo spotify https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc https://repository.spotify.com stable non-free"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
# op et wl-copy : tout appel est tracé (le parcours de Spotify n'en fait aucun).
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
printf 'op %s\n' "$*" >>"$FAKE_DIR/calls"
exit 1
FAKE
cat >"$TEST_TMP/bin/wl-copy" <<'FAKE'
#!/usr/bin/env bash
printf 'wl-copy %s\n' "$*" >>"$FAKE_DIR/calls"
FAKE
# spotify : trace son lancement ; si $FAKE_DIR/client-connecte existe, écrit peu
# après des préférences « connecté », pendant qu'il tourne. Lancé par
# open_detached (setsid), jamais par un « & » du test.
cat >"$TEST_TMP/bin/spotify" <<'FAKE'
#!/usr/bin/env bash
printf 'spotify lancé\n' >>"$FAKE_DIR/calls"
if [[ -e $FAKE_DIR/client-connecte ]]; then
  sleep 0.3
  mkdir -p "$(dirname -- "$SPOTIFY_PREFS")"
  printf 'autologin.canonical_username="121abc"\nautologin.username="121abc"\n' >"$SPOTIFY_PREFS"
fi
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublures, héritées par les sous-shells de module_call.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  case "${args[0]} ${args[1]:-}" in
    "apt-get install")
      [[ -e $TEST_TMP/apt-refuse ]] && return 100
      for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done ;;
    install*) run "${args[@]}" ;;   # copie vers le /etc du dossier temporaire, sans sudo
  esac
  return 0
}
apt_add_repo() { printf 'apt_add_repo %s\n' "$*" >>"$CALLS"; }
export -f run_sudo apt_add_repo
export INSTALLED CALLS TEST_TMP
_APT_UPDATED=1; export _APT_UPDATED
line_of() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }
# Comme le runner (setup.sh) : chaque fonction dans son propre sous-shell.
mcall() { module_call "$MOD" "$1"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }
# Session graphique et réponse au choix « Continuer / Passer » de guided_login.
has_gui() { return 0; }
ui_choose() { printf '%s\n' "${FAKE_CHOICE:-Passer (étape manuelle)}"; }
# write_prefs <contenu> : écrit les préférences du client.
write_prefs() { mkdir -p "$(dirname -- "$SPOTIFY_PREFS")"; printf '%s' "$1" >"$SPOTIFY_PREFS"; }
connected() { write_prefs $'autologin.canonical_username="121abc"\nautologin.username="121abc"\n'; }

printf '%s\n' "== première application (sous-shells du runner) =="
assert_fail "module_check → à faire" mcall module_check
mcall module_install >/dev/null 2>&1; rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_eq "spotify.list posé avec le contenu versionné" "$(cat "$LIST_SRC")" "$(cat "$LIST_FILE" 2>/dev/null)"
assert_fail "spotify.list : aucune entrée de dépôt" grep -qE '^[[:space:]]*deb' "$LIST_FILE"
assert_ok "spotify.list posé avant le dépôt" test "$(line_of spotify.list)" -lt "$(line_of apt_add_repo)"
assert_ok "spotify.list posé avant le paquet" test "$(line_of spotify.list)" -lt "$(line_of 'apt-get install')"
assert_contains "dépôt de Spotify, clé et suite stable non-free" "$(cat "$CALLS")" "$REPO_CALL"
assert_ok "dépôt déclaré avant le paquet" test "$(line_of apt_add_repo)" -lt "$(line_of 'apt-get install')"
assert_contains "paquet spotify-client installé" "$(cat "$INSTALLED")" "spotify-client"
assert_eq "aucune étape déclarée par module_install (la connexion est guidée ensuite)" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_fail "installé, pas connecté → à faire" mcall module_check
out=$(CONNEXION_WAIT_SECONDS=1 FAKE_CHOICE="Passer (étape manuelle)" mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit, même sans connexion (« Passer »)" 0 "$rc"
assert_contains "« Passer » → étape de connexion au résumé" "$(cat "$MANUAL_STEPS_FILE")" "se connecter"
assert_contains "Spotify lancé" "$(cat "$CALLS")" "spotify lancé"
# Client connecté à partir d'ici, jusqu'à la fin du fichier : les module_check à 0
# des sections suivantes en dépendent.
connected
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== déjà installé =="
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
assert_ok "module_install réussit" mcall module_install
assert_eq "rien de réécrit, aucun apt-get install" "$REPO_CALL" "$(cat "$CALLS")"
assert_eq "paquet déjà là → aucune étape" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== spotify.list supprimé ou modifié =="
rm -f "$LIST_FILE"
assert_fail "spotify.list absent → à faire" mcall module_check
assert_ok "module_install le rétablit" mcall module_install
assert_ok "module_check → déjà fait" mcall module_check
printf 'deb https://repository.spotify.com stable non-free\n' >"$LIST_FILE"
assert_fail "spotify.list réécrit par le paquet → à faire" mcall module_check
assert_ok "module_install le rétablit" mcall module_install
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== installation du paquet en échec =="
: >"$INSTALLED"; : >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/apt-refuse"
assert_fail "module_install échoue" mcall module_install
assert_eq "aucune étape de connexion" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_fail "module_check → à faire" mcall module_check
rm -f "$TEST_TMP/apt-refuse"
assert_ok "après correction, module_install réussit" mcall module_install

printf '%s\n' "== module_check sur le paquet =="
assert_ok "paquet présent → déjà fait" mcall module_check
: >"$INSTALLED"
assert_fail "paquet absent → à faire" mcall module_check
printf 'spotify-client\n' >>"$INSTALLED"

printf '%s\n' "== sonde de connexion =="
probe() { mcall _spotify_logged_in; }
connected
assert_ok "autologin.username présent → vrai" probe
write_prefs $'autologin.username=121abc\n'
assert_ok "valeur sans guillemets → vrai" probe
# Relevé en VM : à la déconnexion, seul canonical_username reste.
write_prefs $'autologin.canonical_username="fae123"\nui.language="en"\n'
assert_fail "déconnecté (canonical_username seul) → faux" probe
write_prefs $'autologin.username=""\n'
assert_fail "valeur vide → faux" probe
rm -f "$SPOTIFY_PREFS"
assert_fail "fichier absent → faux" probe
out=$(probe 2>&1)
assert_eq "fichier absent : rien d'affiché" "" "$out"
mkdir -p "$TEST_TMP/xdg/spotify"
printf 'autologin.username="121abc"\n' >"$TEST_TMP/xdg/spotify/prefs"
# shellcheck disable=SC2016  # développé par le bash lancé, pas ici
assert_ok "chemin par défaut sous XDG_CONFIG_HOME" \
  env -u SPOTIFY_PREFS XDG_CONFIG_HOME="$TEST_TMP/xdg" bash -c \
  'source "$1"; source "$2"; _spotify_logged_in' _ "$DOTFILES_DIR/lib/core.sh" "$MOD"

printf '%s\n' "== module_check et connexion =="
connected
assert_ok "paquet, spotify.list et connecté → déjà fait" mcall module_check
write_prefs $'autologin.canonical_username="fae123"\n'
assert_fail "paquet et spotify.list, pas connecté → à faire" mcall module_check

# reset_login : pas connecté, étapes, appels et journal remis à zéro.
reset_login() {
  rm -f "$SPOTIFY_PREFS" "$TEST_TMP/client-connecte"
  : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; : >"$LOG_FILE"
}

printf '%s\n' "== connexion guidée réussie =="
reset_login; touch "$TEST_TMP/client-connecte"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "Spotify lancé" "$(cat "$CALLS")" "spotify lancé"
assert_contains "consigne : le code QR" "$out" "code QR"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_eq "aucun appel à op" 0 "$(count_calls '^op ')"
assert_eq "presse-papiers jamais touché" 0 "$(count_calls '^wl-copy')"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== déjà connecté =="
reset_login; connected
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_eq "Spotify non lancé" 0 "$(count_calls 'spotify lancé')"
assert_not_contains "aucune ouverture tracée au journal" "$(cat "$LOG_FILE")" "(détaché)"
assert_contains "déjà fait annoncé" "$out" "Spotify : déjà fait"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== passer =="
reset_login
out=$(CONNEXION_WAIT_SECONDS=1 FAKE_CHOICE="Passer (étape manuelle)" mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape de connexion au résumé" "$(cat "$MANUAL_STEPS_FILE")" "se connecter"
assert_eq "aucun appel à op" 0 "$(count_calls '^op ')"
assert_eq "presse-papiers jamais touché" 0 "$(count_calls '^wl-copy')"
assert_fail "module_check → à faire" mcall module_check

test_done
