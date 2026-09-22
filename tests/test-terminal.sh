#!/usr/bin/env bash
# tests/test-terminal.sh — module terminal avec un HOME isolé et des doublures
# (dpkg-query, run_sudo, fc-list/fc-cache, update-alternatives, gsettings) :
# aucune installation réelle et aucun réseau — la police est servie en file://,
# avec des noms encodés côté URL comme le fait GitHub.
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

export HOME="$TEST_TMP/home"
mkdir -p "$HOME" "$TEST_TMP/bin"
FONTS_DIR="$TEST_TMP/fonts"
# shellcheck source=../lib/fonts.sh
source "$DOTFILES_DIR/lib/fonts.sh"

export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
FAMILIES="$TEST_TMP/families"; : >"$FAMILIES"
NEXT="$TEST_TMP/families-next"; : >"$NEXT"
SCHEMAS="$TEST_TMP/schemas"; : >"$SCHEMAS"
ALT="$TEST_TMP/alt"; : >"$ALT"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/fc-list" <<'FAKE'
#!/usr/bin/env bash
cat "$FAKE_DIR/families" 2>/dev/null
FAKE
cat >"$TEST_TMP/bin/fc-cache" <<'FAKE'
#!/usr/bin/env bash
printf 'fc-cache %s\n' "$*" >>"$FAKE_DIR/calls"
cp -f "$FAKE_DIR/families-next" "$FAKE_DIR/families"
FAKE
# update-alternatives : --query lit le marqueur (sans être journalisé, sinon il
# fausserait les comptes : module_check l'appelle), --set l'écrit — sauf si le
# fichier « alt-refuse » est présent, pour éprouver le cas non constatable.
cat >"$TEST_TMP/bin/update-alternatives" <<'FAKE'
#!/usr/bin/env bash
case ${1:-} in
  --query)
    printf 'Name: %s\n' "$2"
    [ -s "$FAKE_DIR/alt" ] && printf 'Value: %s\n' "$(cat "$FAKE_DIR/alt")"
    exit 0 ;;
  --set)
    [ -e "$FAKE_DIR/alt-refuse" ] || printf '%s' "$3" >"$FAKE_DIR/alt" ;;
esac
printf 'update-alternatives %s\n' "$*" >>"$FAKE_DIR/calls"
exit 0
FAKE
cat >"$TEST_TMP/bin/gsettings" <<'FAKE'
#!/usr/bin/env bash
case ${1:-} in
  list-schemas) cat "$FAKE_DIR/schemas" 2>/dev/null ;;
  set) printf "'%s'" "$4" >"$FAKE_DIR/gset" ;;
  get) cat "$FAKE_DIR/gset" 2>/dev/null ;;
esac
exit 0
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
# shellcheck source=../modules/21-terminal.sh
source "$DOTFILES_DIR/modules/21-terminal.sh"

# Police servie localement : quatre faux fichiers dont le nom porte de vrais
# espaces, des URL qui les encodent — exactement ce que sert GitHub.
for style in "Regular" "Bold" "Italic" "Bold Italic"; do
  printf 'fausse police\n' >"$TEST_TMP/MesloLGS NF $style.ttf"
done
TERMINAL_FONT_URLS=(
  "file://$TEST_TMP/MesloLGS%20NF%20Regular.ttf"
  "file://$TEST_TMP/MesloLGS%20NF%20Bold.ttf"
  "file://$TEST_TMP/MesloLGS%20NF%20Italic.ttf"
  "file://$TEST_TMP/MesloLGS%20NF%20Bold%20Italic.ttf"
)

run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  if [[ ${args[0]} == apt-get && ${args[1]} == install ]]; then
    for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done
    return 0
  fi
  [[ ${args[0]} == apt-get ]] && return 0
  run "${args[@]}"   # update-alternatives passe par la doublure du PATH
}
count_calls() { grep -c -- "$1" "$CALLS" || true; }
_APT_UPDATED=1

printf '%s\n' "== état initial =="
assert_fail "module_check → à faire" module_check

printf '%s\n' "== module_install =="
printf 'MesloLGS NF\n' >"$NEXT"
assert_ok "réussit" module_install
assert_eq "un seul apt-get install" 1 "$(count_calls 'apt-get install')"
assert_contains "ghostty passé à apt" "$(cat "$CALLS")" "ghostty"
assert_ok "la famille est connue de fontconfig" font_installed "MesloLGS NF"
assert_eq "quatre fichiers de police installés" 4 "$(find "$FONTS_DIR/MesloLGSNF" -name '*.ttf' | wc -l)"
assert_file "nom d'URL décodé" "$FONTS_DIR/MesloLGSNF/MesloLGS NF Bold Italic.ttf"
assert_fail "module_check toujours à faire (configure pas encore passé)" module_check

printf '%s\n' "== module_configure, sans schéma GNOME =="
assert_ok "réussit" module_configure
assert_ok "configuration liée" config_linked config/terminal/ghostty "$HOME/.config/ghostty/config"
assert_contains "alternative enregistrée" "$(cat "$CALLS")" "--install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ghostty"
assert_contains "alternative sélectionnée" "$(cat "$CALLS")" "--set x-terminal-emulator /usr/bin/ghostty"
assert_fail "schéma absent → aucun réglage GNOME écrit" test -e "$TEST_TMP/gset"
assert_ok "Ghostty est le terminal par défaut" _terminal_is_default
assert_ok "module_check → déjà fait" module_check
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== réexécution =="
: >"$CALLS"
assert_ok "module_install réussit" module_install
assert_eq "aucun apt-get install" 0 "$(count_calls 'apt-get install')"
assert_eq "aucun téléchargement de police" 0 "$(count_calls 'fc-cache')"
assert_ok "module_configure réussit" module_configure
assert_eq "aucune nouvelle sélection d'alternative" 0 "$(count_calls -- '--set')"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== schéma GNOME présent =="
printf '%s\n' "org.gnome.desktop.default-applications.terminal" >"$SCHEMAS"
: >"$ALT"
assert_ok "module_configure réussit" module_configure
assert_eq "GNOME reçoit Ghostty" "'/usr/bin/ghostty'" "$(cat "$TEST_TMP/gset")"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== terminal par défaut non constatable =="
: >"$ALT"; touch "$TEST_TMP/alt-refuse"
out=$(module_configure 2>&1); rc=$?
assert_eq "module_configure se termine sans erreur" 0 "$rc"
assert_contains "l'écart est signalé" "$out" "n'a pas pu être constaté"
assert_contains "étape manuelle déclarée" "$(cat "$MANUAL_STEPS_FILE")" "terminal par défaut"
assert_fail "module_check → à faire" module_check
rm -f "$TEST_TMP/alt-refuse"; : >"$MANUAL_STEPS_FILE"
assert_ok "après correction, module_configure rétablit" module_configure
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== module_check : chacune de ses conditions =="
grep -vx ghostty "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
assert_fail "paquet absent → à faire" module_check
printf 'ghostty\n' >>"$INSTALLED"
mv "$FAMILIES" "$TEST_TMP/familles.gardees"; : >"$FAMILIES"
assert_fail "police inconnue de fontconfig → à faire" module_check
mv "$TEST_TMP/familles.gardees" "$FAMILIES"
rm -f "$HOME/.config/ghostty/config"
assert_fail "configuration non liée → à faire" module_check
assert_ok "module_configure la remet" module_configure
: >"$ALT"
assert_fail "alternative ailleurs → à faire" module_check
assert_ok "module_configure la remet" module_configure
assert_ok "module_check → déjà fait" module_check

test_done
