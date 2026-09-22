#!/usr/bin/env bash
# tests/test-cli-tools.sh — module cli-tools avec un HOME isolé et des doublures
# (dpkg-query paramétrable par un fichier de paquets « installés », run_sudo qui
# compte les apt-get et les simule en complétant ce fichier, faux batcat et
# fdfind) : première application, installation partielle, réexécution, nom déjà
# pris, fragment retiré. Aucune installation réelle, aucun réseau.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

# --- HOME isolé et doublures -----------------------------------------------------
export HOME="$TEST_TMP/home"
mkdir -p "$HOME" "$TEST_TMP/bin"
SHELL_COMMON_RC_DIR="$HOME/.commonrc.d"
export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
REAL_ZSH=$(command -v zsh || true)

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
# batcat et fdfind : de vrais exécutables, pour que `command -v` les trouve et
# que les liens pointent vers quelque chose de réel.
for f in batcat fdfind; do
  printf '#!/usr/bin/env bash\nprintf %%s %s\n' "$f" >"$TEST_TMP/bin/$f"
done
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
# shellcheck source=../modules/22-cli-tools.sh
source "$DOTFILES_DIR/modules/22-cli-tools.sh"

# Doublure : journalise l'appel ; `apt-get install` n'est pas exécuté mais son
# effet est simulé en ajoutant les paquets à la liste des installés.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@")
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  if [[ ${args[0]} == apt-get && ${args[1]} == install ]]; then
    local a
    for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done
    return 0
  fi
  [[ ${args[0]} == apt-get ]] && return 0
  run "${args[@]}"
}
count_calls() { grep -c -- "$1" "$CALLS" || true; }
_APT_UPDATED=1
COMMONRC_SUM=$(cksum <"$DOTFILES_DIR/config/shell/commonrc")

printf '%s\n' "== état initial =="
assert_fail "module_check → à faire" module_check

printf '%s\n' "== première application =="
assert_ok "module_install réussit" module_install
assert_eq "un seul apt-get install" 1 "$(count_calls 'apt-get install')"
for pkg in ripgrep fd-find fzf bat zoxide lazygit postgresql-client; do
  assert_contains "$pkg passé à apt" "$(cat "$CALLS")" "$pkg"
done
assert_fail "module_check toujours à faire (configure pas encore passé)" module_check
assert_ok "module_configure réussit" module_configure
assert_ok "le nom bat est un lien" test -L "$HOME/.local/bin/bat"
assert_ok "le nom fd est un lien" test -L "$HOME/.local/bin/fd"
assert_eq "bat vise le batcat du système" "$(readlink -f "$TEST_TMP/bin/batcat")" "$(readlink -f "$HOME/.local/bin/bat")"
assert_eq "fd vise le fdfind du système" "$(readlink -f "$TEST_TMP/bin/fdfind")" "$(readlink -f "$HOME/.local/bin/fd")"
assert_eq "le nom usuel exécute bien l'outil" "batcat" "$("$HOME/.local/bin/bat")"
assert_ok "fragment lié" config_linked config/cli-tools/commonrc.sh "$SHELL_COMMON_RC_DIR/cli-tools.sh"
assert_ok "module_check → déjà fait" module_check
assert_eq "config/shell/commonrc n'a pas été touché" "$COMMONRC_SUM" "$(cksum <"$DOTFILES_DIR/config/shell/commonrc")"

printf '%s\n' "== réexécution =="
: >"$CALLS"
bat_before=$(readlink "$HOME/.local/bin/bat")
assert_ok "module_install réussit" module_install
assert_eq "aucun apt-get install" 0 "$(count_calls 'apt-get install')"
assert_ok "module_configure réussit" module_configure
assert_eq "le lien n'est pas réécrit" "$bat_before" "$(readlink "$HOME/.local/bin/bat")"
assert_fail "aucune sauvegarde du fragment" test -e "$SHELL_COMMON_RC_DIR/cli-tools.sh.bak"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== installation partielle =="
: >"$CALLS"
grep -vx 'fzf' "$INSTALLED" | grep -vx 'lazygit' >"$TEST_TMP/reste" && mv "$TEST_TMP/reste" "$INSTALLED"
assert_fail "module_check → à faire" module_check
assert_ok "module_install réussit" module_install
assert_contains "seuls les manquants sont passés à apt" "$(grep 'apt-get install' "$CALLS")" "fzf lazygit"
assert_not_contains "les paquets présents ne sont pas réinstallés" "$(grep 'apt-get install' "$CALLS")" "ripgrep"

printf '%s\n' "== nom déjà pris par un vrai fichier =="
rm -f "$HOME/.local/bin/fd"
printf '#!/bin/sh\necho maison\n' >"$HOME/.local/bin/fd"; chmod +x "$HOME/.local/bin/fd"
out=$(module_configure 2>&1); rc=$?
assert_eq "module_configure se termine sans erreur" 0 "$rc"
assert_contains "le fichier est signalé" "$out" "laissé intact"
assert_ok "le fichier est resté un fichier ordinaire" test -f "$HOME/.local/bin/fd"
assert_fail "…et n'est pas devenu un lien" test -L "$HOME/.local/bin/fd"
assert_eq "son contenu est intact" "maison" "$("$HOME/.local/bin/fd")"
assert_fail "module_check → à faire tant qu'il est là" module_check
rm -f "$HOME/.local/bin/fd"
assert_ok "retiré puis relancé : le lien est créé" module_configure
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== fragment retiré =="
rm -f "$SHELL_COMMON_RC_DIR/cli-tools.sh"
assert_fail "module_check → à faire" module_check
assert_ok "module_configure le remet" module_configure
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== contenu du fragment dans les trois shells =="
# Chargé comme sur un vrai poste : par ~/.commonrc, qui lit ~/.commonrc.d/*.sh.
ln -sfn "$DOTFILES_DIR/config/shell/commonrc" "$HOME/.commonrc"
FRAG_SHELLS=(sh bash)
[[ -n $REAL_ZSH ]] && FRAG_SHELLS+=("$REAL_ZSH")
for frag_sh in "${FRAG_SHELLS[@]}"; do
  # shellcheck disable=SC2016  # expansions volontairement laissées au shell lancé
  out=$(env -i HOME="$HOME" PATH=/usr/bin:/bin "$frag_sh" -c \
    '. "$HOME/.commonrc"; printf "%s" "$FZF_DEFAULT_COMMAND"' 2>/dev/null)
  assert_contains "$(basename -- "$frag_sh") : FZF_DEFAULT_COMMAND fondé sur fd" "$out" "fd "
done

test_done
