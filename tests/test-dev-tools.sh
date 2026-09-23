#!/usr/bin/env bash
# tests/test-dev-tools.sh — module dev-tools avec un HOME isolé (.zshrc et .bashrc
# témoins), un faux `curl` qui sert des installateurs locaux, et deux faux
# installateurs : celui de twg ajoute, comme le vrai, une ligne à ~/.zshrc quand
# ~/.local/bin manque au PATH. Aucun réseau, aucun outil réel installé.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

export HOME="$TEST_TMP/home"
mkdir -p "$HOME" "$TEST_TMP/bin"
printf '# zshrc témoin\n' >"$HOME/.zshrc"; printf '# bashrc témoin\n' >"$HOME/.bashrc"
SHELL_SUMS=$(cat "$HOME/.zshrc" "$HOME/.bashrc" | cksum)
export FAKE_DIR="$TEST_TMP"
CALLS="$TEST_TMP/calls"; : >"$CALLS"

# Faux curl : `curl … <url> -o <cible>` copie l'installateur local correspondant,
# échoue si le marqueur « curl-refuse » est posé.
cat >"$TEST_TMP/bin/curl" <<'FAKE'
#!/usr/bin/env bash
url="" out=""
while [ $# -gt 0 ]; do
  case $1 in -o) out=$2; shift ;; http*) url=$1 ;; esac
  shift
done
printf 'curl %s\n' "$url" >>"$FAKE_DIR/calls"
[ -e "$FAKE_DIR/curl-refuse" ] && exit 22
case $url in
  *claude.ai*) cp "$FAKE_DIR/claude-install.sh" "$out" ;;
  *teamwork-graph*) cp "$FAKE_DIR/twg-install.sh" "$out" ;;
  *) exit 22 ;;
esac
FAKE
cat >"$TEST_TMP/claude-install.sh" <<'FAKE'
printf 'installateur claude %s\n' "$*" >>"$FAKE_DIR/calls"
mkdir -p "$HOME/.local/share/claude/versions" "$HOME/.local/bin"
printf '#!/bin/sh\necho "9.9.9 (Claude Code)"\n' >"$HOME/.local/share/claude/versions/9.9.9"
chmod +x "$HOME/.local/share/claude/versions/9.9.9"
ln -sfn "$HOME/.local/share/claude/versions/9.9.9" "$HOME/.local/bin/claude"
FAKE
# Comme le vrai (install, lignes 676-684) : ~/.local/bin absent du PATH → ligne
# ajoutée au profil du shell.
cat >"$TEST_TMP/twg-install.sh" <<'FAKE'
printf 'installateur twg %s\n' "$*" >>"$FAKE_DIR/calls"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) printf '\n# Added by Teamwork Graph CLI installer\nexport PATH="%s:$PATH"\n' "$HOME/.local/bin" >>"$HOME/.zshrc" ;;
esac
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\necho twg\n' >"$HOME/.local/bin/twg"; chmod +x "$HOME/.local/bin/twg"
FAKE
chmod +x "$TEST_TMP/bin/"*
# PATH du runner sans ~/.local/bin : le cas du poste neuf (D2).
export PATH="$TEST_TMP/bin:/usr/bin:/bin"
# shellcheck source=../modules/42-dev-tools.sh
source "$DOTFILES_DIR/modules/42-dev-tools.sh"
count_calls() { grep -c -- "$1" "$CALLS" || true; }

printf '%s\n' "== état initial =="
assert_fail "module_check → à faire" module_check

printf '%s\n' "== première installation =="
assert_ok "module_install réussit" module_install
assert_eq "deux téléchargements" 2 "$(count_calls '^curl ')"
assert_contains "installateur de Claude Code sans argument" "$(cat "$CALLS")" $'installateur claude \n'
assert_eq "twg installé sans interaction, connexion ni skills" 1 "$(grep -cx 'installateur twg --yes --skip-login --skip-skills' "$CALLS")"
assert_eq "fichiers du shell intacts" "$SHELL_SUMS" "$(cat "$HOME/.zshrc" "$HOME/.bashrc" | cksum)"
assert_ok "claude répond" "$HOME/.local/bin/claude"
assert_ok "module_check → déjà fait" module_check
out=$(module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape : connexion de Claude Code" "$(cat "$MANUAL_STEPS_FILE")" "Connecter Claude Code"
assert_contains "étape : twg login" "$(cat "$MANUAL_STEPS_FILE")" "twg login"
assert_ok "module_check reste « déjà fait » (connexions hors critère)" module_check

printf '%s\n' "== connexions faites =="
: >"$MANUAL_STEPS_FILE"
mkdir -p "$HOME/.claude" "$HOME/.config/twg"
: >"$HOME/.claude/.credentials.json"; : >"$HOME/.config/twg/auth_oauth.conf"
assert_ok "module_configure réussit" module_configure
assert_eq "aucune étape de connexion" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== réexécution =="
: >"$CALLS"
assert_ok "module_install réussit" module_install
assert_eq "aucun téléchargement" 0 "$(count_calls '^curl ')"

printf '%s\n' "== un seul outil manquant =="
rm -f "$HOME/.local/bin/twg"; : >"$CALLS"
assert_fail "twg absent → à faire" module_check
assert_ok "module_install réussit" module_install
assert_eq "un seul téléchargement, celui de twg" "1 1" "$(count_calls '^curl ') $(count_calls 'curl https://teamwork-graph')"
rm -f "$HOME/.local/bin/claude"
assert_fail "claude absent → à faire" module_check
ln -sfn "$HOME/.local/share/claude/versions/disparue" "$HOME/.local/bin/claude"
assert_fail "lien claude cassé → à faire" module_check
: >"$CALLS"
assert_ok "module_install le réinstalle" module_install
assert_eq "un seul téléchargement, celui de Claude Code" "1 1" "$(count_calls '^curl ') $(count_calls 'curl https://claude.ai')"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== téléchargement en échec =="
rm -f "$HOME/.local/bin/twg"; touch "$TEST_TMP/curl-refuse"
out=$(module_install 2>&1); rc=$?
assert_ok "module_install échoue" test "$rc" -ne 0
assert_contains "l'échec nomme l'URL" "$out" "https://teamwork-graph.atlassian.com/cli/install"
assert_eq "aucun installateur exécuté" 0 "$(count_calls 'installateur twg')"
rm -f "$TEST_TMP/curl-refuse"

printf '%s\n' "== installateur qui ne pose pas la commande =="
cat >"$TEST_TMP/twg-install.sh" <<'FAKE'
printf 'installateur twg %s\n' "$*" >>"$FAKE_DIR/calls"
FAKE
out=$(module_install 2>&1); rc=$?
assert_ok "module_install échoue" test "$rc" -ne 0
assert_contains "l'échec nomme l'outil" "$out" "twg introuvable"

printf '%s\n' "== témoin : sans la mise en PATH, le faux twg écrit dans ~/.zshrc =="
_dev_tools_path() { :; }
cat >"$TEST_TMP/twg-install.sh" <<'FAKE'
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) printf 'export PATH="%s:$PATH"\n' "$HOME/.local/bin" >>"$HOME/.zshrc" ;;
esac
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\n' >"$HOME/.local/bin/twg"; chmod +x "$HOME/.local/bin/twg"
FAKE
export PATH="$TEST_TMP/bin:/usr/bin:/bin"
module_install >/dev/null 2>&1
assert_contains "le faux installateur de twg écrit bien dans ~/.zshrc sans D2" "$(cat "$HOME/.zshrc")" "export PATH="

test_done
