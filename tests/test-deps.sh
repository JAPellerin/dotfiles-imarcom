#!/usr/bin/env bash
# tests/test-deps.sh — setup.sh en boîte noire : découverte, --list, validation
# du graphe (cycle, dépendance inconnue, module invalide), noms inconnus, ordre
# d'exécution (dépendances d'abord, 1password avancé). Aucun sudo : un faux
# `sudo` est placé en tête du PATH et les factices n'ont pas d'effet système.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

fake_sudo
export FIXTURE_STATE_DIR="$TEST_TMP/etat" WSL_DISTRO_NAME=test
# setup <args...> : lance le runner sur les factices, sortie complète capturée.
setup() { MODULES_DIR="$FIXTURES_DIR/modules" bash "$DOTFILES_DIR/setup.sh" "$@" 2>&1; }
rc_of() { local rc=0; "$@" >/dev/null 2>&1 || rc=$?; printf '%s' "$rc"; }

printf '%s\n' "== --list =="
out=$(setup --list)
assert_eq "--list réussit" 0 "$(rc_of setup --list)"
assert_contains "groupe et nom" "$out" "[systeme] base"
assert_contains "description" "$out" "Paquets de base"
assert_contains "état à faire" "$out" "à faire"
assert_contains "module graphique non disponible sans GUI" "$out" "non disponible ici"
assert_eq "un module par ligne (7 factices)" 7 "$(printf '%s\n' "$out" | wc -l)"
assert_not_contains "--list n'exécute rien" "$out" "install base"

printf '%s\n' "== --help et options =="
assert_contains "--help affiche l'usage" "$(setup --help)" "Usage : setup.sh"
assert_eq "option inconnue → code 1" 1 "$(rc_of setup --zzz)"

printf '%s\n' "== refus en root =="
if unshare -r true 2>/dev/null; then
  out=$(MODULES_DIR="$FIXTURES_DIR/modules" unshare -r bash "$DOTFILES_DIR/setup.sh" --list 2>&1) && rc=0 || rc=$?
  assert_eq "lancé en root (unshare -r) → code 1" 1 "$rc"
  assert_contains "message explicite" "$out" "Ne pas lancer en root"
else
  printf '  (unshare -r indisponible : refus root non testé ici)\n'
fi

printf '%s\n' "== validation du graphe =="
out=$(MODULES_DIR="$FIXTURES_DIR/cycle" bash "$DOTFILES_DIR/setup.sh" --list 2>&1) && rc=0 || rc=$?
assert_eq "cycle → code 1" 1 "$rc"
assert_contains "cycle nommé" "$out" "Dépendance circulaire : c → d → c"
out=$(MODULES_DIR="$FIXTURES_DIR/dep-inconnue" bash "$DOTFILES_DIR/setup.sh" --list 2>&1) && rc=0 || rc=$?
assert_eq "dépendance inconnue → code 1" 1 "$rc"
assert_contains "dépendance et module nommés" "$out" "« e » dépend de « zzz », qui n'existe pas"
out=$(MODULES_DIR="$FIXTURES_DIR/contrat" bash "$DOTFILES_DIR/setup.sh" --list 2>&1) && rc=0 || rc=$?
assert_eq "module invalide → refus de démarrer" 1 "$rc"
assert_contains "fichier et champ nommés" "$out" "00-sans-desc.sh : MODULE_DESC manquant"
mkdir -p "$TEST_TMP/vide"
out=$(MODULES_DIR="$TEST_TMP/vide" bash "$DOTFILES_DIR/setup.sh" --list 2>&1) && rc=0 || rc=$?
assert_eq "dossier sans module → code 1" 1 "$rc"

printf '%s\n' "== noms en argument =="
out=$(setup navigateurz) && rc=0 || rc=$?
assert_eq "nom inconnu → code 1" 1 "$rc"
assert_contains "nom inconnu cité" "$out" "« navigateurz »"
assert_contains "noms valides listés" "$out" "Modules valides : base 1password b a echec dependant gui"
assert_not_contains "rien n'est exécuté" "$out" "Ordre d'exécution"

printf '%s\n' "== ordre d'exécution =="
ordre() { setup "$@" | sed -n 's/^→ Ordre d.exécution : //p'; }
assert_eq "dépendances d'abord (a → b a)" "b a" "$(ordre a)"
assert_eq "1password et ses dépendances avancés (a 1password → base 1password b a)" "base 1password b a" "$(ordre a 1password)"
assert_eq "scénario de la spec : git-like, 1password, base → base 1password puis le reste" "base 1password b a" "$(ordre a 1password base)"
assert_eq "chaque module une seule fois" "b a" "$(ordre a b a)"
assert_eq "--all : tous, 1password avancé, ordre des fichiers sinon" "base 1password b a echec dependant gui" "$(ordre --all)"

test_done
