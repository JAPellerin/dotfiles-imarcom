#!/usr/bin/env bash
# tests/test-node.sh — module node avec un NVM_DIR isolé : un faux nvm.sh définit
# une fonction `nvm` pilotée par des fichiers (versions installées, LTS « du
# moment », alias default) qui simule install, alias et `exec … npm install -g` ;
# ensure_git_clone est doublé. Aucun réseau, aucun Node réel.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

export HOME="$TEST_TMP/home"
mkdir -p "$HOME"
printf '# zshrc témoin\n' >"$HOME/.zshrc"; printf '# bashrc témoin\n' >"$HOME/.bashrc"
SHELL_SUMS=$(cat "$HOME/.zshrc" "$HOME/.bashrc" | cksum)
export NVM_DIR="$TEST_TMP/nvm"
export FAKE_DIR="$TEST_TMP"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
printf '24' >"$TEST_TMP/lts-major"          # LTS « du moment »
printf 'v24.21.0' >"$TEST_TMP/remote-lts"   # ce que `nvm install --lts` installerait
printf 'v26.10.0' >"$TEST_TMP/remote-26"    # ce que `nvm install 26` installerait

# Faux nvm.sh : copié dans NVM_DIR par la doublure d'ensure_git_clone.
cat >"$TEST_TMP/nvm.sh" <<'FAKE'
# shellcheck shell=bash
_fake_installed() { ls "$NVM_DIR/versions/node" 2>/dev/null | sort -V; }
_fake_resolve() {   # <majeure> → plus haute version installée, sinon N/A
  local v; v=$(_fake_installed | grep "^v$1\." | tail -1)
  printf '%s\n' "${v:-N/A}"
}
nvm() {
  case $1 in
    version)
      case $2 in
        "lts/*") _fake_resolve "$(cat "$FAKE_DIR/lts-major")" ;;
        default) if [ -s "$NVM_DIR/alias/default" ]; then _fake_resolve "$(cat "$NVM_DIR/alias/default")"; else echo N/A; fi ;;
        *) _fake_resolve "$2" ;;
      esac ;;
    install)
      printf 'nvm %s\n' "$*" >>"$FAKE_DIR/calls"
      local v
      if [ "$2" = --lts ]; then v=$(cat "$FAKE_DIR/remote-lts"); else v=$(cat "$FAKE_DIR/remote-$2"); fi
      mkdir -p "$NVM_DIR/versions/node/$v/lib/node_modules/npm" ;;
    alias)
      printf 'nvm %s\n' "$*" >>"$FAKE_DIR/calls"
      mkdir -p "$NVM_DIR/alias"; printf '%s' "$3" >"$NVM_DIR/alias/$2" ;;
    exec)
      printf 'nvm %s\n' "$*" >>"$FAKE_DIR/calls"
      local v=$2 spec=$6 name ver
      case $spec in
        pnpm@*) name=pnpm; ver="${spec#pnpm@}.27.1" ;;
        *) name=$spec; ver=1.14.0 ;;
      esac
      [ -e "$FAKE_DIR/npm-refuse" ] && return 1
      mkdir -p "$NVM_DIR/versions/node/$v/lib/node_modules/$name"
      printf '{"name":"%s","version":"%s"}\n' "$name" "$ver" >"$NVM_DIR/versions/node/$v/lib/node_modules/$name/package.json" ;;
  esac
}
FAKE

# shellcheck source=../modules/40-node.sh
source "$DOTFILES_DIR/modules/40-node.sh"
ensure_git_clone() {
  printf 'ensure_git_clone %s\n' "$*" >>"$CALLS"
  [[ -e $2 ]] && return 0
  mkdir -p "$2"; cp "$TEST_TMP/nvm.sh" "$2/nvm.sh"
}
count_calls() { grep -c -- "$1" "$CALLS" || true; }
node_versions() { find "$NVM_DIR/versions/node" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -V | tr '\n' ' ' | sed 's/ $//'; }
pkg_version() { jq -r .version "$NVM_DIR/versions/node/$1/lib/node_modules/$2/package.json" 2>/dev/null; }

printf '%s\n' "== état initial =="
assert_fail "module_check → à faire (pas de nvm)" module_check

printf '%s\n' "== première application =="
assert_ok "module_install réussit" module_install
assert_contains "nvm cloné à l'étiquette fixée" "$(cat "$CALLS")" \
  "ensure_git_clone https://github.com/nvm-sh/nvm.git $NVM_DIR --branch v0.40.8 --depth 1"
assert_eq "nvm install --lts" 1 "$(count_calls 'nvm install --lts')"
assert_eq "nvm install 26" 1 "$(count_calls 'nvm install 26')"
assert_ok "module_configure réussit" module_configure
assert_eq "défaut sur la 26" "26" "$(cat "$NVM_DIR/alias/default")"
assert_eq "pnpm 11 sous la LTS" "11.27.1" "$(pkg_version v24.21.0 pnpm)"
assert_eq "pnpm 11 sous la 26" "11.27.1" "$(pkg_version v26.10.0 pnpm)"
assert_eq "openspec sous la 26" "1.14.0" "$(pkg_version v26.10.0 @fission-ai/openspec)"
assert_eq "openspec absent sous la LTS" "" "$(pkg_version v24.21.0 @fission-ai/openspec)"
assert_ok "module_check → déjà fait" module_check
assert_eq "fichiers du shell intacts" "$SHELL_SUMS" "$(cat "$HOME/.zshrc" "$HOME/.bashrc" | cksum)"

printf '%s\n' "== réexécution =="
: >"$CALLS"
assert_ok "module_install réussit" module_install
assert_eq "seul nvm install --lts (rafraîchit la LTS)" "1 0" "$(count_calls 'nvm install --lts') $(count_calls 'nvm install 26')"
assert_ok "module_configure réussit" module_configure
assert_eq "aucun alias ni npm install" 0 "$(count_calls -E 'nvm (alias|exec)')"

printf '%s\n' "== une 26 déjà là, sans LTS (cas de la WSL) =="
rm -rf "$NVM_DIR"; : >"$CALLS"
mkdir -p "$NVM_DIR/versions/node/v26.8.2/lib/node_modules" "$NVM_DIR/alias"
cp "$TEST_TMP/nvm.sh" "$NVM_DIR/nvm.sh"; printf '26' >"$NVM_DIR/alias/default"
mkdir -p "$NVM_DIR/versions/node/v26.8.2/lib/node_modules/pnpm" "$NVM_DIR/versions/node/v26.8.2/lib/node_modules/@fission-ai/openspec"
printf '{"version":"11.26.0"}' >"$NVM_DIR/versions/node/v26.8.2/lib/node_modules/pnpm/package.json"
printf '{"version":"1.13.0"}' >"$NVM_DIR/versions/node/v26.8.2/lib/node_modules/@fission-ai/openspec/package.json"
assert_fail "module_check → à faire (LTS absente)" module_check
assert_ok "module_install réussit" module_install
assert_eq "nvm install --lts seul, aucun nvm install 26" "1 0" "$(count_calls 'nvm install --lts') $(count_calls 'nvm install 26')"
assert_ok "module_configure réussit" module_configure
assert_eq "aucune nouvelle 26" "v24.21.0 v26.8.2" "$(node_versions)"
assert_eq "défaut inchangé, pas d'alias réécrit" 0 "$(count_calls 'nvm alias')"
assert_eq "pnpm installé sous la LTS seulement" 1 "$(count_calls 'npm install -g pnpm@11')"
assert_contains "… sous la v24.21.0" "$(grep 'pnpm@11' "$CALLS")" "exec v24.21.0"
assert_eq "openspec déjà là → pas réinstallé" 0 "$(count_calls openspec)"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== LTS devenue la 26 =="
rm -rf "$NVM_DIR"; : >"$CALLS"
printf '26' >"$TEST_TMP/lts-major"; printf 'v26.10.0' >"$TEST_TMP/remote-lts"
assert_ok "module_install réussit" module_install
assert_eq "la LTS apporte la 26 → aucun nvm install 26" 0 "$(count_calls 'nvm install 26')"
assert_ok "module_configure réussit" module_configure
assert_eq "une seule version" "v26.10.0" "$(node_versions)"
assert_eq "un seul pnpm installé" 1 "$(count_calls 'npm install -g pnpm@11')"
assert_ok "module_check → déjà fait" module_check
printf '24' >"$TEST_TMP/lts-major"; printf 'v24.21.0' >"$TEST_TMP/remote-lts"

printf '%s\n' "== pnpm d'une autre majeure =="
printf '{"version":"12.5.1"}' >"$NVM_DIR/versions/node/v26.10.0/lib/node_modules/pnpm/package.json"
printf '26' >"$TEST_TMP/lts-major"; : >"$CALLS"
assert_fail "pnpm 12 → à faire" module_check
assert_ok "module_configure réussit" module_configure
assert_eq "remplacé par une 11" "11.27.1" "$(pkg_version v26.10.0 pnpm)"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== npm en échec =="
rm -rf "$NVM_DIR/versions/node/v26.10.0/lib/node_modules/@fission-ai"; touch "$TEST_TMP/npm-refuse"
assert_fail "openspec manquant, npm refuse → module_configure échoue" module_configure
rm -f "$TEST_TMP/npm-refuse"
assert_ok "après correction, module_configure réussit" module_configure
printf '24' >"$TEST_TMP/lts-major"

printf '%s\n' "== module_check : chacune de ses conditions =="
rm -rf "$NVM_DIR"; module_install >/dev/null 2>&1; module_configure >/dev/null 2>&1
assert_ok "module_check → déjà fait" module_check
mv "$NVM_DIR/nvm.sh" "$TEST_TMP/nvm.sh.garde"
assert_fail "nvm absent → à faire" module_check
mv "$TEST_TMP/nvm.sh.garde" "$NVM_DIR/nvm.sh"
mv "$NVM_DIR/versions/node/v24.21.0" "$TEST_TMP/lts.garde"
assert_fail "LTS absente → à faire" module_check
mv "$TEST_TMP/lts.garde" "$NVM_DIR/versions/node/v24.21.0"
printf '24' >"$NVM_DIR/alias/default"
assert_fail "défaut sur la LTS → à faire" module_check
printf '26' >"$NVM_DIR/alias/default"
rm -rf "$NVM_DIR/versions/node/v24.21.0/lib/node_modules/pnpm"
assert_fail "pnpm absent sous la LTS → à faire" module_check
module_configure >/dev/null 2>&1
rm -rf "$NVM_DIR/versions/node/v26.10.0/lib/node_modules/@fission-ai"
assert_fail "openspec absent sous la 26 → à faire" module_check
module_configure >/dev/null 2>&1
assert_ok "module_check → déjà fait" module_check
assert_eq "fichiers du shell toujours intacts" "$SHELL_SUMS" "$(cat "$HOME/.zshrc" "$HOME/.bashrc" | cksum)"

test_done
