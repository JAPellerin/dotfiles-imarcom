#!/usr/bin/env bash
# tests/test-shell.sh — module shell avec un HOME isolé et des doublures
# (dpkg-query, git, chsh, sudo, getent, zsh) : première application, réexécution.
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
SHELL_COMMON_RC="$HOME/.commonrc"
export FAKE_DIR="$TEST_TMP"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
printf '/bin/bash' >"$TEST_TMP/login-shell"
cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
printf 'install ok installed'
FAKE
# git : `clone` crée un faux dépôt (.git/origin) ; `-C <dir> remote get-url origin` le relit.
cat >"$TEST_TMP/bin/git" <<'FAKE'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$FAKE_DIR/calls"
if [[ $1 == clone ]]; then
  url=${*: -2:1}; dir=${*: -1}
  mkdir -p "$dir/.git" && printf '%s' "$url" >"$dir/.git/origin"
elif [[ $1 == -C && $3 == remote ]]; then
  cat "$2/.git/origin"
fi
FAKE
cat >"$TEST_TMP/bin/chsh" <<'FAKE'
#!/usr/bin/env bash
printf 'chsh %s\n' "$*" >>"$FAKE_DIR/calls"
printf '%s' "$2" >"$FAKE_DIR/login-shell"
FAKE
cat >"$TEST_TMP/bin/getent" <<'FAKE'
#!/usr/bin/env bash
printf 'u:x:1000:1000::/home/u:%s\n' "$(cat "$FAKE_DIR/login-shell")"
FAKE
cat >"$TEST_TMP/bin/zsh" <<'FAKE'
#!/usr/bin/env bash
exit 0
FAKE
chmod +x "$TEST_TMP/bin/"*
fake_sudo
export PATH="$TEST_TMP/bin:$PATH"
# shellcheck source=../modules/20-shell.sh
source "$DOTFILES_DIR/modules/20-shell.sh"
# .bashrc « d'Ubuntu » minimal, avec un ancien ajout manuel pour déclencher l'avertissement.
cat >"$HOME/.bashrc" <<'RC'
# ~/.bashrc
PS1="\u@\h:\w\$ "
[ -f "$HOME/.commonrc" ] && . "$HOME/.commonrc"
RC
printf 'ancien zshrc\n' >"$HOME/.zshrc"

printf '%s\n' "== état initial =="
assert_fail "module_check → à faire" module_check

printf '%s\n' "== module_install =="
assert_ok "réussit" module_install
assert_eq "quatre dépôts clonés" 4 "$(grep -c '^git clone' "$CALLS")"
assert_ok "oh-my-zsh cloné complet (sans --depth)" bash -c "grep '^git clone' '$CALLS' | grep ohmyzsh | grep -qv -- --depth"
assert_eq "thème et plugins clonés en --depth=1" 3 "$(grep '^git clone' "$CALLS" | grep -c -- '--depth=1')"
assert_file "oh-my-zsh présent" "$HOME/.oh-my-zsh/.git/origin"
assert_file "powerlevel10k présent" "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/.git/origin"
assert_file "zsh-syntax-highlighting présent" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/.git/origin"
assert_fail "module_check toujours à faire (configure pas encore passé)" module_check

printf '%s\n' "== module_configure =="
out=$(module_configure 2>&1); rc=$?
assert_eq "réussit" 0 "$rc"
assert_ok ".zshrc lié" config_linked config/shell/zshrc "$HOME/.zshrc"
assert_ok ".commonrc lié" config_linked config/shell/commonrc "$HOME/.commonrc"
assert_ok ".p10k.zsh lié" config_linked config/shell/p10k.zsh "$HOME/.p10k.zsh"
assert_eq "ancien .zshrc sauvegardé" "ancien zshrc" "$(cat "$HOME/.zshrc.bak")"
assert_eq "une ligne bashrc-extra dans .bashrc" 1 "$(grep -c 'bashrc-extra.sh' "$HOME/.bashrc")"
assert_contains "la ligne vise le fichier du dépôt" "$(cat "$HOME/.bashrc")" "$DOTFILES_DIR/config/shell/bashrc-extra.sh"
assert_ok ".bashrc reste valide" bash -n "$HOME/.bashrc"
assert_contains "anciens ajouts manuels signalés" "$out" "anciens ajouts manuels"
assert_eq "chsh appelé une fois, vers zsh" "chsh -s $TEST_TMP/bin/zsh $USER" "$(grep '^chsh' "$CALLS")"
assert_contains "effet à la prochaine session annoncé" "$out" "prochaine session"
assert_contains "Nerd Font mentionnée" "$out" "Nerd Font"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== réexécution =="
assert_ok "module_check → déjà fait" module_check
: >"$CALLS"
assert_ok "module_install réussit" module_install
assert_ok "module_configure réussit" module_configure
assert_eq "aucun clone ni chsh relancé (seules des lectures git remote)" 0 "$(grep -cE "^(git clone|chsh)" "$CALLS")"
assert_eq "toujours une seule ligne bashrc-extra" 1 "$(grep -c 'bashrc-extra.sh' "$HOME/.bashrc")"
assert_fail "pas de nouvelle sauvegarde" test -e "$HOME/.zshrc.bak-"*

printf '%s\n' "== dérives détectées par module_check =="
rm "$HOME/.p10k.zsh"
assert_fail "lien manquant → à faire" module_check
module_configure >/dev/null 2>&1
printf '/bin/bash' >"$TEST_TMP/login-shell"
assert_fail "shell de connexion revenu à bash → à faire" module_check

test_done
