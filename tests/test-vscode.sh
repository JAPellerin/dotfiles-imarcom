#!/usr/bin/env bash
# tests/test-vscode.sh — module vscode avec des doublures (dpkg-query, run_sudo
# qui journalise, simule apt-get install et copie le fichier passé à
# debconf-set-selections, apt_add_repo qui compte, faux `code` piloté par un
# fichier d'extensions installées) : aucune installation réelle, aucun réseau.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

mkdir -p "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
EXTS="$TEST_TMP/extensions"; : >"$EXTS"
DEBCONF="$TEST_TMP/debconf-recu"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
# Faux code : --list-extensions lit le fichier, --install-extension l'ajoute —
# ou échoue si l'identifiant figure dans « extensions-refusees ».
cat >"$TEST_TMP/bin/code" <<'FAKE'
#!/usr/bin/env bash
case ${1:-} in
  --list-extensions) cat "$FAKE_DIR/extensions" ;;
  --install-extension)
    printf 'code --install-extension %s\n' "$2" >>"$FAKE_DIR/calls"
    grep -qxF -- "$2" "$FAKE_DIR/extensions-refusees" 2>/dev/null && exit 1
    printf '%s\n' "$2" >>"$FAKE_DIR/extensions" ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
export VSCODE_BIN="$TEST_TMP/bin/code"
# shellcheck source=../modules/51-vscode.sh
source "$DOTFILES_DIR/modules/51-vscode.sh"

run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  case "${args[0]} ${args[1]:-}" in
    "apt-get install") for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done ;;
    # Le fichier passé en argument, pas l'entrée standard : c'est ce qui atteint
    # réellement debconf-set-selections (D2, D6).
    debconf-set-selections*) cp "${args[1]}" "$DEBCONF" ;;
  esac
  return 0
}
apt_add_repo() { printf 'apt_add_repo %s\n' "$*" >>"$CALLS"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }
line_of() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }
_APT_UPDATED=1
WANTED=$(grep -v '^#' "$DOTFILES_DIR/config/vscode/extensions.txt" | grep -v '^$')

printf '%s\n' "== liste versionnée =="
assert_eq "18 extensions" 18 "$(wc -l <<<"$WANTED")"
assert_eq "_vscode_wanted lit la liste" "$WANTED" "$(_vscode_wanted)"
assert_contains "anthropic.claude-code listée" "$WANTED" "anthropic.claude-code"

printf '%s\n' "== première application =="
assert_fail "module_check → à faire" module_check
assert_ok "module_install réussit" module_install
assert_eq "sélection debconf reçue par la commande" "code code/add-microsoft-repo boolean false" "$(cat "$DEBCONF" 2>/dev/null)"
assert_ok "debconf réglé avant l'installation" test "$(line_of debconf-set-selections)" -lt "$(line_of 'apt-get install')"
assert_ok "dépôt déclaré avant l'installation" test "$(line_of apt_add_repo)" -lt "$(line_of 'apt-get install')"
assert_contains "dépôt Microsoft" "$(cat "$CALLS")" \
  "apt_add_repo vscode https://packages.microsoft.com/keys/microsoft.asc https://packages.microsoft.com/repos/code stable main"
assert_contains "code et gnome-keyring passés à apt" "$(grep 'apt-get install' "$CALLS")" "code gnome-keyring"
assert_fail "module_check toujours à faire (extensions)" module_check
assert_ok "module_configure réussit" module_configure
assert_eq "18 extensions installées" 18 "$(count_calls 'code --install-extension')"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== réexécution =="
: >"$CALLS"
assert_ok "module_configure réussit" module_configure
assert_eq "aucune installation d'extension" 0 "$(count_calls 'code --install-extension')"

printf '%s\n' "== extensions partielles, casse différente, hors liste =="
grep -v -e '^eamodio.gitlens$' -e '^vitest.explorer$' -e '^anthropic.claude-code$' "$EXTS" >"$TEST_TMP/reste"
{ cat "$TEST_TMP/reste"; printf 'Anthropic.Claude-Code\nquelqu.un-autre\n'; } >"$EXTS"; : >"$CALLS"
assert_fail "module_check → à faire" module_check
assert_ok "module_configure réussit" module_configure
assert_eq "seules les deux manquantes" "code --install-extension eamodio.gitlens
code --install-extension vitest.explorer" "$(sort "$CALLS")"
assert_contains "extension hors liste conservée" "$(cat "$EXTS")" "quelqu.un-autre"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== commentaires et lignes vides =="
cp "$VSCODE_EXTENSIONS_FILE" "$TEST_TMP/liste.garde"
VSCODE_EXTENSIONS_FILE="$TEST_TMP/liste"
printf '# en-tête\n\n  redhat.vscode-yaml  # yaml\n\nnouvelle.extension\n' >"$VSCODE_EXTENSIONS_FILE"
assert_eq "deux identifiants lus" $'redhat.vscode-yaml\nnouvelle.extension' "$(_vscode_wanted)"
assert_fail "extension ajoutée à la liste → à faire" module_check
: >"$CALLS"
assert_ok "module_configure réussit" module_configure
assert_eq "seule la nouvelle installée" "code --install-extension nouvelle.extension" "$(cat "$CALLS")"
VSCODE_EXTENSIONS_FILE="$TEST_TMP/liste.garde"

printf '%s\n' "== extension introuvable =="
grep -v '^yzhang.markdown-all-in-one$' "$EXTS" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$EXTS"
printf 'yzhang.markdown-all-in-one\n' >"$TEST_TMP/extensions-refusees"
out=$(module_configure 2>&1); rc=$?
assert_ok "module_configure échoue" test "$rc" -ne 0
assert_contains "l'échec nomme l'extension" "$out" "yzhang.markdown-all-in-one"
rm -f "$TEST_TMP/extensions-refusees"
assert_ok "après correction, module_configure réussit" module_configure

printf '%s\n' "== module_check : chacune de ses conditions =="
assert_ok "module_check → déjà fait" module_check
grep -vx code "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
assert_fail "code absent → à faire" module_check
printf 'code\n' >>"$INSTALLED"
grep -vx gnome-keyring "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
assert_fail "gnome-keyring absent → à faire" module_check
printf 'gnome-keyring\n' >>"$INSTALLED"
grep -vx ms-playwright.playwright "$EXTS" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$EXTS"
assert_fail "une extension absente → à faire" module_check
printf 'ms-playwright.playwright\n' >>"$EXTS"
assert_ok "module_check → déjà fait" module_check

test_done
