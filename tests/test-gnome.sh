#!/usr/bin/env bash
# tests/test-gnome.sh — module gnome avec des doublures : racine /etc du test
# (GNOME_ETC) ; sudo factice (run_sudo et install_system_file restent les vrais) ;
# dpkg-query et apt-get (paquets dans un fichier) ; dconf factice (`update` touche
# la base compilée, échec sur drapeau ; `read`/`write` du dock dans un fichier ;
# appels tracés, sauf `read`). Fonctions du module
# appelées par module_call, comme le fait le runner.
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
fake_sudo
export FAKE_DIR="$TEST_TMP" GNOME_ETC="$TEST_TMP/etc"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
MOD="$DOTFILES_DIR/modules/70-gnome.sh"
PROFILE="$GNOME_ETC/dconf/profile/user"
KEYFILE="$GNOME_ETC/dconf/db/local.d/00-dotfiles"
DB="$GNOME_ETC/dconf/db/local"
SRC="$DOTFILES_DIR/config/gnome/reglages.dconf"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/apt-get" <<'FAKE'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$FAKE_DIR/calls"
[[ $1 == install ]] || exit 0
shift; for a in "$@"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$FAKE_DIR/installed"; done
FAKE
cat >"$TEST_TMP/bin/dconf" <<'FAKE'
#!/usr/bin/env bash
if [[ $1 == read ]]; then cat "$FAKE_DIR/dock" 2>/dev/null; exit 0; fi
printf 'dconf %s\n' "$*" >>"$FAKE_DIR/calls"
if [[ $1 == write ]]; then printf '%s\n' "$3" >"$FAKE_DIR/dock"; exit 0; fi
[[ $1 == update ]] || exit 0
[[ -e $FAKE_DIR/dconf-refuse ]] && { echo "error: invalid keyfile" >&2; exit 1; }
mkdir -p "$GNOME_ETC/dconf/db"; : >"$GNOME_ETC/dconf/db/local"
FAKE
chmod +x "$TEST_TMP/bin/"*
export INSTALLED CALLS TEST_TMP
_APT_UPDATED=1; export _APT_UPDATED
mcall() { module_call "$MOD" "$1"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }
meta() { bash -c 'source "$1"; printf "%s" "${!2:-}"' _ "$MOD" "$1"; }

printf '%s\n' "== métadonnées =="
assert_eq "groupe bureau" "bureau" "$(meta MODULE_GROUP)"
assert_eq "session graphique requise" "1" "$(meta MODULE_NEEDS_GUI)"
assert_fail "description sans virgule ni | (module_meta)" grep -qE '^MODULE_DESC=.*[,|]' "$MOD"
assert_ok "métadonnées acceptées par module_meta" module_meta "$MOD"

printf '%s\n' "== fichier des réglages de base =="
# key <section> <clé=valeur> : la section du fichier porte cette ligne.
key() { awk -v s="[$1]" -v k="$2" '$0 == s { f = 1; next } /^\[/ { f = 0 } f && $0 == k { found = 1 } END { exit !found }' "$SRC"; }
assert_ok "clavier canadien français" key org/gnome/desktop/input-sources "sources=[('xkb', 'ca')]"
assert_ok "thème sombre" key org/gnome/desktop/interface "color-scheme='prefer-dark'"
assert_ok "fond d'écran" key org/gnome/desktop/background "picture-uri='file:///usr/share/backgrounds/osselo-Ask_a_friend.jpg'"
assert_ok "fond de l'écran verrouillé" key org/gnome/desktop/screensaver "picture-uri='file:///usr/share/backgrounds/osselo-Ask_a_friend.jpg'"
assert_ok "dock en bas" key org/gnome/shell/extensions/dash-to-dock "dock-position='BOTTOM'"
assert_ok "dock masqué automatiquement" key org/gnome/shell/extensions/dash-to-dock "dock-fixed=false"
assert_ok "dock sans corbeille" key org/gnome/shell/extensions/dash-to-dock "show-trash=false"
assert_ok "icônes du dock de 42" key org/gnome/shell/extensions/dash-to-dock "dash-max-icon-size=42"
assert_ok "pas d'icône du dossier personnel" key org/gnome/shell/extensions/ding "show-home=false"
assert_ok "pas de rapports d'erreur" key org/gnome/desktop/privacy "report-technical-problems=false"
assert_ok "localisation coupée" key org/gnome/system/location "enabled=false"
assert_ok "veilleuse sans horaire automatique" key org/gnome/settings-daemon/plugins/color "night-light-schedule-automatic=false"
assert_ok "dossiers en premier" key org/gtk/gtk4/settings/file-chooser "sort-directories-first=true"
dock=$(sed -n "s/^favorite-apps=//p" "$SRC")
assert_eq "dock : applications dans l'ordre (Fichiers, Ghostty, navigateurs, 1Password, VS Code, …, éditeur de texte)" \
  "['org.gnome.Nautilus.desktop', 'com.mitchellh.ghostty.desktop', 'brave-browser.desktop', 'firefox.desktop', 'google-chrome.desktop', 'com.onepassword.OnePassword.desktop', 'com.microsoft.VSCode.desktop', 'com.anthropic.Claude.desktop', 'thunderbird.desktop', 'rocketchat-desktop.desktop', 'md.obsidian.Obsidian.desktop', 'spotify.desktop', 'org.gnome.TextEditor.desktop']" "$dock"
for ecarte in 'numlock-state' 'settings-daemon/plugins/power' 'org/gnome/mutter' 'tiling-assistant' 'app-picker-layout' 'enabled-extensions'; do
  assert_fail "clé écartée absente : $ecarte" grep -q -- "$ecarte" "$SRC"
done

printf '%s\n' "== premier passage =="
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_install réussit" mcall module_install
assert_contains "dconf-cli installé" "$(cat "$INSTALLED")" "dconf-cli"
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "profil dconf écrit" "$(printf 'user-db:user\nsystem-db:local')" "$(cat "$PROFILE")"
assert_ok "réglages écrits tels quels" cmp -s "$SRC" "$KEYFILE"
assert_eq "réglages en 0644" 644 "$(stat -c %a "$KEYFILE")"
assert_eq "dconf update une fois" 1 "$(count_calls 'dconf update')"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== relance =="
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucun sudo ni recompilation" "" "$(cat "$CALLS")"

printf '%s\n' "== réglages du dépôt modifiés =="
printf '# ancienne version\n' >"$KEYFILE"
assert_fail "fichier différent → à faire" mcall module_check
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_ok "fichier réécrit" cmp -s "$SRC" "$KEYFILE"
assert_eq "recompilé" 1 "$(count_calls 'dconf update')"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== base compilée absente ou plus ancienne =="
rm -f "$DB"
assert_fail "base absente → à faire" mcall module_check
: >"$CALLS"; mcall module_configure >/dev/null 2>&1
assert_eq "base absente → recompilée" 1 "$(count_calls 'dconf update')"
touch -d '1 hour ago' "$DB"; touch "$KEYFILE"
assert_fail "base plus ancienne que les réglages → à faire" mcall module_check
: >"$CALLS"; mcall module_configure >/dev/null 2>&1
assert_eq "base plus ancienne → recompilée" 1 "$(count_calls 'dconf update')"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== profil existant différent =="
printf 'user-db:user\nsystem-db:site\n' >"$PROFILE"
: >"$CALLS"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure échoue" 1 "$rc"
assert_contains "échec qui nomme le profil" "$out" "$PROFILE"
assert_eq "profil intact" "$(printf 'user-db:user\nsystem-db:site')" "$(cat "$PROFILE")"
assert_eq "aucune recompilation" 0 "$(count_calls 'dconf update')"
assert_fail "module_check → à faire" mcall module_check
printf 'user-db:user\nsystem-db:local\n' >"$PROFILE"

printf '%s\n' "== dconf update en échec =="
printf '# autre\n' >"$KEYFILE"; touch "$TEST_TMP/dconf-refuse"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure échoue" 1 "$rc"
assert_contains "échec nommé" "$out" "dconf update a échoué"
rm -f "$TEST_TMP/dconf-refuse"
mcall module_configure >/dev/null 2>&1

printf '%s\n' "== dock d'Ubuntu (première connexion) =="
UBUNTU="['firefox_firefox.desktop', 'org.gnome.Nautilus.desktop', 'snap-store_snap-store.desktop', 'org.gnome.Yelp.desktop', 'org.gnome.Ptyxis.desktop']"
printf '%s\n' "$UBUNTU" >"$TEST_TMP/dock"
assert_fail "dock d'Ubuntu → à faire" mcall module_check
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "dock du dépôt écrit" "$dock" "$(cat "$TEST_TMP/dock")"
assert_eq "écrit à la clé du dock" 1 "$(count_calls 'dconf write /org/gnome/shell/favorite-apps')"
assert_eq "sans sudo ni recompilation" 0 "$(count_calls 'sudo\|dconf update')"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== dock modifié par l'utilisateur =="
printf '%s\n' "['org.gnome.Nautilus.desktop', 'brave-browser.desktop']" >"$TEST_TMP/dock"
assert_ok "module_check → déjà fait" mcall module_check
: >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "dock intact" "['org.gnome.Nautilus.desktop', 'brave-browser.desktop']" "$(cat "$TEST_TMP/dock")"
assert_eq "aucune écriture" 0 "$(count_calls 'dconf write')"
rm -f "$TEST_TMP/dock"
assert_ok "dock sans valeur (défaut du système) → déjà fait" mcall module_check

printf '%s\n' "== liste du dock mise à jour dans le dépôt =="
OLD="['org.gnome.Nautilus.desktop', 'ancienne.desktop']"
# old_keyfile : réglages déployés par une version antérieure du dépôt (autre dock).
old_keyfile() { sed "s/^favorite-apps=.*/favorite-apps=$OLD/" "$SRC" >"$KEYFILE"; }
old_keyfile; printf '%s\n' "$OLD" >"$TEST_TMP/dock"
assert_fail "réglages déployés anciens → à faire" mcall module_check
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_eq "ancienne liste du dépôt → nouvelle liste écrite" "$dock" "$(cat "$TEST_TMP/dock")"
assert_contains "mise à jour annoncée" "$out" "Dock mis à jour"
assert_ok "module_check → déjà fait" mcall module_check
old_keyfile; printf '%s\n' "['org.gnome.Nautilus.desktop', 'ancienne.desktop', 'org.gnome.TextEditor.desktop']" >"$TEST_TMP/dock"
: >"$CALLS"
assert_ok "dock retouché, dépôt mis à jour : module_configure réussit" mcall module_configure
assert_eq "dock retouché intact" "['org.gnome.Nautilus.desktop', 'ancienne.desktop', 'org.gnome.TextEditor.desktop']" "$(cat "$TEST_TMP/dock")"
assert_eq "aucune écriture du dock" 0 "$(count_calls 'dconf write')"
printf '%s\n' "$dock" >"$TEST_TMP/dock"
: >"$CALLS"
assert_ok "relance, dock du dépôt : module_configure réussit" mcall module_configure
assert_eq "aucune écriture" "" "$(cat "$CALLS")"
rm -f "$TEST_TMP/dock"

printf '%s\n' "== dconf-cli absent =="
: >"$INSTALLED"
assert_fail "sans dconf-cli → à faire" mcall module_check

test_done
