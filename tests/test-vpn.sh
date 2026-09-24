#!/usr/bin/env bash
# tests/test-vpn.sh — module vpn avec des doublures (dpkg-query lu dans un
# fichier ; run_sudo qui journalise et simule apt-get install ; faux nmcli qui lit
# les connexions et leurs types de service dans des fichiers, ou échoue). Les
# fonctions du module sont appelées par module_call, chacune dans son sous-shell,
# comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

mkdir -p "$TEST_TMP/bin" "$TEST_TMP/nm"
export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
NMCLI_LOG="$TEST_TMP/nmcli-log"; : >"$NMCLI_LOG"
CONNS="$TEST_TMP/nm/connections"; : >"$CONNS"
MOD="$DOTFILES_DIR/modules/65-vpn.sh"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
# Faux nmcli : connexions « UUID:TYPE » dans nm/connections, type de service
# d'une connexion VPN dans nm/<uuid> (absent → échec) ; nmcli-refuse le fait
# échouer, nmcli-absent le fait répondre comme une commande introuvable. La
# lecture du type de service vide son entrée standard, comme le ferait un
# programme qui la lit : la boucle du module doit la protéger.
cat >"$TEST_TMP/bin/nmcli" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_DIR/nmcli-log"
[[ -e $FAKE_DIR/nmcli-absent ]] && { printf 'nmcli: command not found\n' >&2; exit 127; }
[[ -e $FAKE_DIR/nmcli-refuse ]] && { printf 'Error: NetworkManager is not running.\n' >&2; exit 8; }
case "$*" in
  "-t -f UUID,TYPE connection show") cat "$FAKE_DIR/nm/connections" ;;
  "-g vpn.service-type connection show uuid "*)
    [[ -t 0 ]] || cat >/dev/null
    cat "$FAKE_DIR/nm/${*: -1}" 2>/dev/null || exit 10 ;;
  *) exit 2 ;;
esac
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublure, héritée par les sous-shells de module_call.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  if [[ "${args[0]} ${args[1]:-}" == "apt-get install" ]]; then
    for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done
  fi
  return 0
}
export -f run_sudo
export INSTALLED CALLS
_APT_UPDATED=1; export _APT_UPDATED
# Comme le runner (setup.sh) : chaque fonction dans son propre sous-shell.
mcall() { module_call "$MOD" "$1"; }
# add_conn <uuid> <type> [service-type]
add_conn() {
  printf '%s:%s\n' "$1" "$2" >>"$CONNS"
  [[ -n ${3:-} ]] && printf '%s\n' "$3" >"$TEST_TMP/nm/$1"
  return 0
}
IMPORT="Importer le profil VPN de l'équipe TI"

printf '%s\n' "== première application =="
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_install réussit" mcall module_install
assert_contains "openvpn passé à apt" "$(grep 'apt-get install' "$CALLS")" " openvpn "
assert_contains "greffon GNOME passé à apt" "$(grep 'apt-get install' "$CALLS")" "network-manager-openvpn-gnome"
assert_ok "module_configure réussit" mcall module_configure
assert_contains "aucun profil → étape d'import au résumé" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"
assert_fail "paquets installés, aucun profil → toujours à faire" mcall module_check

printf '%s\n' "== paquets déjà installés (bureau Ubuntu), aucun profil =="
: >"$CALLS"; : >"$MANUAL_STEPS_FILE"
add_conn 1111-eth ethernet
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_install réussit" mcall module_install
assert_eq "aucun appel à apt" "" "$(cat "$CALLS")"
assert_ok "module_configure réussit" mcall module_configure
assert_contains "étape d'import déclarée" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"

printf '%s\n' "== connexion VPN d'un autre type =="
: >"$MANUAL_STEPS_FILE"
add_conn 2222-wg vpn org.freedesktop.NetworkManager.wireguard
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_contains "étape d'import déclarée" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"

printf '%s\n' "== connexion VPN au type de service illisible =="
: >"$MANUAL_STEPS_FILE"
add_conn 2323-illisible vpn
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_contains "étape d'import déclarée" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"

printf '%s\n' "== profil OpenVPN importé =="
# Listé après les connexions VPN WireGuard et illisible : la boucle les passe
# sans perdre la suite de la liste.
: >"$MANUAL_STEPS_FILE"
add_conn 3333-ovpn vpn org.freedesktop.NetworkManager.openvpn
assert_ok "module_check → déjà fait" mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucune étape déclarée" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== nmcli en échec =="
: >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/nmcli-refuse"
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_configure réussit malgré tout" mcall module_configure
assert_contains "étape d'import déclarée" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"
rm -f "$TEST_TMP/nmcli-refuse"

printf '%s\n' "== nmcli absent =="
# Code 127 du shell pour une commande introuvable ; pas de retrait du PATH, un
# vrai nmcli pourrait se trouver dans /usr/bin.
: >"$MANUAL_STEPS_FILE"; touch "$TEST_TMP/nmcli-absent"
assert_fail "module_check → à faire" mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_contains "étape d'import déclarée" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"
rm -f "$TEST_TMP/nmcli-absent"

printf '%s\n' "== lecture seule =="
assert_not_contains "aucune commande nmcli qui écrit" "$(cat "$NMCLI_LOG")" " add"
assert_not_contains "aucun nmcli modify" "$(cat "$NMCLI_LOG")" "modify"
assert_not_contains "aucun nmcli import" "$(cat "$NMCLI_LOG")" "import"

printf '%s\n' "== module_check : chacune de ses conditions =="
assert_ok "module_check → déjà fait" mcall module_check
for pkg in openvpn network-manager-openvpn-gnome; do
  grep -vx "$pkg" "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
  assert_fail "$pkg absent → à faire" mcall module_check
  printf '%s\n' "$pkg" >>"$INSTALLED"
done
grep -v '^3333-ovpn:' "$CONNS" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$CONNS"
assert_fail "profil OpenVPN retiré → à faire" mcall module_check

test_done
