#!/usr/bin/env bash
# tests/test-files.sh — lib/files.sh : liens de config (sauvegarde, réapplication,
# source absente), clonage git idempotent (dépôt local file://) et copie de
# fichiers système (faux sudo, /etc dans le dossier temporaire).
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"

# Dépôt factice : DOTFILES_DIR pointe sur un faux dépôt dans le dossier temporaire.
DOTFILES_DIR="$TEST_TMP/depot"
mkdir -p "$DOTFILES_DIR/config/shell" "$TEST_TMP/home"
printf 'contenu-depot\n' >"$DOTFILES_DIR/config/shell/zshrc"
cible="$TEST_TMP/home/.zshrc"
# nb_bak : nombre de sauvegardes (.bak*) dans le faux home.
nb_bak() { local n=0 f; for f in "$TEST_TMP"/home/.*.bak*; do [[ -e $f ]] && n=$((n + 1)); done; printf '%s' "$n"; }

printf '%s\n' "== link_config : première application (fichier ordinaire) =="
printf 'ancien\n' >"$cible"
assert_ok "réussit" link_config config/shell/zshrc "$cible"
assert_ok "la cible est un lien" test -L "$cible"
assert_eq "le lien pointe vers le dépôt" "$DOTFILES_DIR/config/shell/zshrc" "$(readlink "$cible")"
assert_eq "l'ancien fichier est sauvegardé en .bak" "ancien" "$(cat "$cible.bak")"
assert_ok "config_linked vrai" config_linked config/shell/zshrc "$cible"

printf '%s\n' "== link_config : réapplication =="
out=$(link_config config/shell/zshrc "$cible" 2>&1); rc=$?
assert_eq "réussit" 0 "$rc"
assert_contains "signale « déjà en place »" "$out" "déjà en place"
assert_eq "aucune nouvelle sauvegarde" 1 "$(nb_bak)"

printf '%s\n' "== link_config : .bak déjà présent → sauvegarde datée =="
rm "$cible"; printf 'encore-un\n' >"$cible"
assert_ok "réussit" link_config config/shell/zshrc "$cible"
assert_eq ".bak d'origine intact" "ancien" "$(cat "$cible.bak")"
assert_eq "second fichier sauvegardé sous un nom daté" "encore-un" "$(cat "$cible".bak-*)"

printf '%s\n' "== link_config : lien étranger remplacé sans sauvegarde =="
rm "$cible"; ln -s /etc/hostname "$cible"
n_before=$(nb_bak)
assert_ok "réussit" link_config config/shell/zshrc "$cible"
assert_ok "le lien pointe maintenant vers le dépôt" config_linked config/shell/zshrc "$cible"
assert_eq "pas de sauvegarde pour un lien" "$n_before" "$(nb_bak)"

printf '%s\n' "== link_config : source absente =="
printf 'a-garder\n' >"$TEST_TMP/home/.autre"
out=$(link_config config/shell/inexistant "$TEST_TMP/home/.autre" 2>&1); rc=$?
assert_eq "échoue" 1 "$rc"
assert_contains "nomme le fichier attendu" "$out" "config/shell/inexistant"
assert_eq "la cible est intacte" "a-garder" "$(cat "$TEST_TMP/home/.autre")"
assert_fail "config_linked faux pour un fichier ordinaire" config_linked config/shell/zshrc "$TEST_TMP/home/.autre"
assert_ok "link_config crée le dossier parent" link_config config/shell/zshrc "$TEST_TMP/home/.config/sub/zshrc"

printf '%s\n' "== ensure_git_clone =="
src="$TEST_TMP/origine"
git init -q "$src" && git -C "$src" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
url="file://$src"
assert_ok "premier clonage" ensure_git_clone "$url" "$TEST_TMP/clone"
assert_file "dépôt cloné" "$TEST_TMP/clone/.git/HEAD"
out=$(ensure_git_clone "$url" "$TEST_TMP/clone" 2>&1); rc=$?
assert_eq "réexécution réussit" 0 "$rc"
assert_contains "réexécution : déjà cloné" "$out" "Déjà cloné"
assert_contains "git clone journalisé" "$(cat "$LOG_FILE")" "git clone"
assert_eq "un seul clone journalisé" 1 "$(grep -c 'git clone' "$LOG_FILE")"
git init -q "$TEST_TMP/etranger" && git -C "$TEST_TMP/etranger" remote add origin https://example.invalid/autre.git
out=$(ensure_git_clone "$url" "$TEST_TMP/etranger" 2>&1); rc=$?
assert_eq "dossier étranger → échec" 1 "$rc"
assert_contains "le dossier est nommé" "$out" "$TEST_TMP/etranger"
mkdir -p "$TEST_TMP/clone/pasgit"   # sous un dépôt git : git -C ne doit pas remonter au parent
out=$(ensure_git_clone "$url" "$TEST_TMP/clone/pasgit" 2>&1); rc=$?
assert_eq "dossier non git → échec" 1 "$rc"
assert_contains "dossier non git nommé comme tel, même sous un dépôt git" "$out" "n'est pas un dépôt git"
assert_ok "options passées à git clone (--depth 1)" ensure_git_clone "$url" "$TEST_TMP/clone2" --depth 1
assert_ok "URL avec ou sans .git considérées identiques" ensure_git_clone "$url.git" "$TEST_TMP/clone"

printf '%s\n' "== install_system_file =="
fake_sudo
etc="$TEST_TMP/etc"
printf 'Pin-Priority: 1000\n' >"$DOTFILES_DIR/config/shell/mozilla.pref"
nb_install() { grep -c 'install -m' "$LOG_FILE" || true; }
assert_ok "première écriture (dossiers parents créés)" install_system_file config/shell/mozilla.pref "$etc/apt/preferences.d/mozilla"
assert_eq "contenu copié" "Pin-Priority: 1000" "$(cat "$etc/apt/preferences.d/mozilla")"
assert_eq "mode 0644 par défaut" 644 "$(stat -c %a "$etc/apt/preferences.d/mozilla")"
assert_fail "la cible est une copie, pas un lien" test -L "$etc/apt/preferences.d/mozilla"
n=$(nb_install)
out=$(install_system_file config/shell/mozilla.pref "$etc/apt/preferences.d/mozilla" 2>&1); rc=$?
assert_eq "contenu identique : réussit" 0 "$rc"
assert_contains "contenu identique : « déjà à jour »" "$out" "Déjà à jour"
assert_eq "contenu identique : aucun install" "$n" "$(nb_install)"
printf 'Pin-Priority: 900\n' >"$DOTFILES_DIR/config/shell/mozilla.pref"
assert_ok "contenu différent : réécrit" install_system_file config/shell/mozilla.pref "$etc/apt/preferences.d/mozilla"
assert_eq "nouveau contenu en place" "Pin-Priority: 900" "$(cat "$etc/apt/preferences.d/mozilla")"
printf 'repo_add_once="false"\n' >"$TEST_TMP/tmp-default"
assert_ok "source absolue (fichier temporaire) et mode explicite" install_system_file "$TEST_TMP/tmp-default" "$etc/default/google-chrome" 0600
assert_eq "mode explicite appliqué" 600 "$(stat -c %a "$etc/default/google-chrome")"
out=$(install_system_file config/shell/inexistant "$etc/jamais" 2>&1); rc=$?
assert_eq "source relative absente → échec" 1 "$rc"
assert_contains "source absente nommée" "$out" "config/shell/inexistant"
assert_fail "cible intacte (non créée)" test -e "$etc/jamais"
assert_fail "source absolue absente → échec" install_system_file "$TEST_TMP/nexiste-pas" "$etc/jamais"

test_done
