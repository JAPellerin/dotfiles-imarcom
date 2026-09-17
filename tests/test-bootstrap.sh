#!/usr/bin/env bash
# tests/test-bootstrap.sh — bootstrap.sh en boîte noire, hors ligne : prérequis
# présents (pas d'apt), parcours git pull sur un clone d'un dépôt bare local,
# refus d'un dossier étranger / d'un dépôt étranger / de root, étape en échec.
# Le clone HTTPS réel est vérifié à la main (tâche 5.1) et en VM (5.4).
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

# Dépôt « distant » local dont le nom contient dotfiles-imarcom (contrôle d'origine).
BARE="$TEST_TMP/JAPellerin/dotfiles-imarcom.git"
mkdir -p "$(dirname "$BARE")" && git init -q --bare "$BARE"
WORK="$TEST_TMP/work"
git clone -q "$BARE" "$WORK" 2>/dev/null
cp "$DOTFILES_DIR/setup.sh" "$WORK/"; cp -r "$DOTFILES_DIR/lib" "$DOTFILES_DIR/modules" "$WORK/"
git -C "$WORK" -c user.name=t -c user.email=t@t add -A
git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm "v1"
git -C "$WORK" push -q origin HEAD:main 2>/dev/null
CLONE="$TEST_TMP/dotfiles"
git clone -q "$BARE" "$CLONE" 2>/dev/null
# Une mise à jour côté distant pour prouver le git pull.
printf '# v2\n' >>"$WORK/setup.sh"
git -C "$WORK" -c user.name=t -c user.email=t@t commit -qam "v2"
git -C "$WORK" push -q origin HEAD:main 2>/dev/null

BOOTSTRAP="$DOTFILES_DIR/bootstrap.sh"
boot() { DOTFILES_DIR="$1" bash "$BOOTSTRAP" "${@:2}" 2>&1; }

printf '%s\n' "== parcours git pull =="
out=$(boot "$CLONE" --list) && rc=0 || rc=$?
assert_eq "code de sortie 0" 0 "$rc"
assert_contains "prérequis déjà installés (aucun apt)" "$out" "déjà installés"
assert_contains "dépôt mis à jour" "$out" "mis à jour (git pull)"
assert_contains "le pull a bien ramené la v2" "$(tail -1 "$CLONE/setup.sh")" "# v2"
assert_contains "setup.sh du clone lancé avec les arguments" "$out" "[systeme] base"

printf '%s\n' "== refus =="
mkdir -p "$TEST_TMP/pasgit"
out=$(boot "$TEST_TMP/pasgit" --list) && rc=0 || rc=$?
assert_eq "dossier non git → code 1" 1 "$rc"
assert_contains "message nommant le dossier" "$out" "$TEST_TMP/pasgit existe mais n'est pas un dépôt git"
assert_fail "rien n'a été écrit dans le dossier" test -e "$TEST_TMP/pasgit/setup.sh"
git init -q "$TEST_TMP/etranger" && git -C "$TEST_TMP/etranger" remote add origin https://exemple.test/autre.git
out=$(boot "$TEST_TMP/etranger" --list) && rc=0 || rc=$?
assert_eq "dépôt git étranger → code 1" 1 "$rc"
assert_contains "origine étrangère citée" "$out" "origin : https://exemple.test/autre.git"
if unshare -r true 2>/dev/null; then
  out=$(DOTFILES_DIR="$CLONE" unshare -r bash "$BOOTSTRAP" 2>&1) && rc=0 || rc=$?
  assert_eq "root → code 1" 1 "$rc"
  assert_contains "message root" "$out" "Ne pas lancer en root"
fi

printf '%s\n' "== étape en échec =="
out=$(boot /proc/impossible --list) && rc=0 || rc=$?
assert_fail "code non nul" test "$rc" -eq 0
assert_contains "l'étape fautive est nommée" "$out" "Échec à l'étape « [2/3] dépôt /proc/impossible »"
assert_contains "commande de relance rappelée" "$out" "curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | bash"

test_done
