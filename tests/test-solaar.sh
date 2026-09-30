#!/usr/bin/env bash
# tests/test-solaar.sh — module solaar avec des doublures : dpkg-query (paquets
# « installés » dans un fichier), apt-get (ajoute les paquets, trace ses appels),
# sudo factice. Fonctions du module appelées par module_call, comme le fait le
# runner. Aucune installation réelle, aucun réseau.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
fake_sudo
export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
MOD="$DOTFILES_DIR/modules/71-solaar.sh"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/apt-get" <<'FAKE'
#!/usr/bin/env bash
printf 'apt-get %s (frontend=%s)\n' "$*" "${DEBIAN_FRONTEND:-}" >>"$FAKE_DIR/calls"
[[ $1 == install ]] || exit 0
shift; for a in "$@"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$FAKE_DIR/installed"; done
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
assert_eq "dépend de base seulement" "base" "$(meta MODULE_DEPS)"
assert_fail "description sans virgule ni | (module_meta)" grep -qE '^MODULE_DESC=.*[,|]' "$MOD"
assert_ok "métadonnées acceptées par module_meta" module_meta "$MOD"

printf '%s\n' "== première installation =="
assert_fail "sans le paquet → à faire" mcall module_check
assert_ok "module_install réussit" mcall module_install
assert_contains "paquet solaar installé" "$(cat "$INSTALLED")" "solaar"
assert_eq "un seul apt-get install" 1 "$(count_calls 'apt-get install')"
assert_contains "installation non interactive (debconf à sa valeur par défaut)" "$(cat "$CALLS")" "frontend=noninteractive"
assert_ok "module_configure réussit" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== relance =="
: >"$CALLS"
assert_ok "module_install réussit" mcall module_install
assert_eq "aucun apt-get install" 0 "$(count_calls 'apt-get install')"
assert_eq "aucun apt-get du tout (donc aucun sudo)" "" "$(cat "$CALLS")"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== paquet retiré =="
: >"$INSTALLED"
assert_fail "paquet retiré → à faire" mcall module_check

test_done
