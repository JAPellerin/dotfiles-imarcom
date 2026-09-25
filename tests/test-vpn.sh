#!/usr/bin/env bash
# tests/test-vpn.sh — module vpn avec des doublures (dpkg-query lu dans un
# fichier ; run_sudo qui journalise et simule apt-get install ; faux nmcli à état
# — connexions, types de service, vpn.data, secret, permissions, import, modify,
# éditeur qui répète son entrée standard, delete, échecs sur demande ; faux op —
# session, profil factice avec une fausse clé repérable, identifiant et mot de
# passe avec « , », « \ » et « : »). Les fonctions du module sont appelées par
# module_call, chacune dans son sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

mkdir -p "$TEST_TMP/bin" "$TEST_TMP/nm"
export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
NMCLI_LOG="$TEST_TMP/nmcli-log"; : >"$NMCLI_LOG"
CONNS="$TEST_TMP/nm/connections"; : >"$CONNS"
MOD="$DOTFILES_DIR/modules/65-vpn.sh"
export XDG_RUNTIME_DIR="$TEST_TMP/run" VPN_CERT_DIR="$TEST_TMP/certs"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
# Faux nmcli : connexions « UUID:TYPE » dans nm/connections, type de service
# d'une connexion VPN dans nm/<uuid> (absent → échec) ; nmcli-refuse le fait
# échouer, nmcli-absent le fait répondre comme une commande introuvable. La
# lecture du type de service vide son entrée standard, comme le ferait un
# programme qui la lit : la boucle du module doit la protéger. Arguments tracés
# dans nmcli-log (jamais l'entrée standard). État d'une connexion créée par
# import : nm/<uuid>.data (vpn.data, format de la valeur), nm/<uuid>.secret
# (valeur enregistrée, en clair), nm/<uuid>.autoconnect. Drapeaux : perm (valeur
# de settings.modify.system, yes par défaut), import-refuse, import-noop,
# modify-refuse, edit-refuse, edit-noop (réussit sans rien enregistrer),
# edit-alter (enregistre autre chose), edit-interrupt (interrompt le module).
cat >"$TEST_TMP/bin/nmcli" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_DIR/nmcli-log"
[[ -e $FAKE_DIR/nmcli-absent ]] && { printf 'nmcli: command not found\n' >&2; exit 127; }
[[ -e $FAKE_DIR/nmcli-refuse ]] && { printf 'Error: NetworkManager is not running.\n' >&2; exit 8; }
NM=$FAKE_DIR/nm
# gform : forme de -g — « \ » doublé, « : » précédé d'un « \ ».
gform() { local v=${1//\\/\\\\}; printf '%s' "${v//:/\\:}"; }
case "$*" in
  "-t -f UUID,TYPE connection show") cat "$NM/connections" ;;
  "-g vpn.service-type connection show uuid "*)
    [[ -t 0 ]] || cat >/dev/null
    cat "$NM/${*: -1}" 2>/dev/null || exit 10 ;;
  "-t -f PERMISSION,VALUE general permissions")
    printf 'org.freedesktop.NetworkManager.settings.modify.own:yes\n'
    printf 'org.freedesktop.NetworkManager.settings.modify.system:%s\n' "$(cat "$FAKE_DIR/perm" 2>/dev/null || echo yes)" ;;
  "connection import type openvpn file "*)
    f=${*: -1}
    stat -c 'import-file %a' "$f" >>"$FAKE_DIR/nmcli-log"
    [[ -e $FAKE_DIR/import-refuse ]] && { echo "Error: failed to import" >&2; exit 1; }
    name=$(basename -- "$f" .ovpn)
    mkdir -p "$VPN_CERT_DIR"
    for k in ca cert key tls-crypt; do printf 'faux\n' >"$VPN_CERT_DIR/$name-$k.pem"; done
    [[ -e $FAKE_DIR/import-noop ]] && exit 0
    u=$(cat /proc/sys/kernel/random/uuid)
    printf '%s:vpn\n' "$u" >>"$NM/connections"
    printf 'org.freedesktop.NetworkManager.openvpn\n' >"$NM/$u"
    printf 'connection-type = password-tls, remote = vpn.example.invalid\:1194' >"$NM/$u.data"
    printf 'yes' >"$NM/$u.autoconnect"
    printf "Connection '%s' (%s) successfully added.\n" "$name" "$u" ;;
  "connection modify uuid "*)
    [[ -e $FAKE_DIR/modify-refuse ]] && { echo "Error: modify" >&2; exit 1; }
    u=$4; shift 4
    while (( $# )); do
      case $1 in
        connection.autoconnect) printf '%s' "$2" >"$NM/$u.autoconnect"; shift 2 ;;
        +vpn.data) printf ', %s' "${2/=/ = }" >>"$NM/$u.data"; shift 2 ;;
        *) shift ;;
      esac
    done ;;
  "connection edit uuid "*)
    u=${*: -1}; input=$(cat)
    printf 'nmcli> %s\n' "$input"          # comme le vrai : l'entrée répétée
    [[ -e $FAKE_DIR/edit-refuse ]] && exit 1
    if [[ -e $FAKE_DIR/edit-interrupt ]]; then kill -INT "$PPID"; kill -INT $$; fi
    [[ -e $FAKE_DIR/edit-noop ]] && exit 0
    line=$(grep '^set vpn.secrets password = ' <<<"$input") || exit 1
    v=${line#set vpn.secrets password = }
    # Désechappement de l'éditeur : « \\ » → « \ », « \, » → « , ».
    v=${v//'\\'/$'\x01'}; v=${v//'\,'/,}; v=${v//$'\x01'/'\'}
    [[ -e $FAKE_DIR/edit-alter ]] && v="$v-autre"
    printf '%s' "$v" >"$NM/$u.secret" ;;
  "-g vpn.data connection show uuid "*) gform "$(cat "$NM/${*: -1}.data")"; echo ;;
  "--show-secrets -g vpn.secrets connection show uuid "*)
    f="$NM/${*: -1}.secret"
    [[ -f $f ]] && { v=$(cat "$f"); printf 'password = %s\n' "$(gform "${v//,/\\,}")"; } ;;
  "connection delete uuid "*)
    u=${*: -1}
    grep -v "^$u:" "$NM/connections" >"$NM/reste"; mv "$NM/reste" "$NM/connections"
    rm -f "$NM/$u" "$NM/$u".* ;;
  *) exit 2 ;;
esac
FAKE
# Faux op : session si $FAKE_DIR/session ; lectures tracées dans calls.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read) printf 'op read %s\n' "${*: -1}" >>"$FAKE_DIR/calls"
        case ${*: -1} in
          op://Imarcom/VPN/jpellerin.ovpn)
            [[ -e $FAKE_DIR/ovpn-refuse ]] && { echo "[ERROR] item 'Imarcom/VPN' does not have a field 'jpellerin.ovpn'" >&2; exit 1; }
            [[ -e $FAKE_DIR/ovpn-empty ]] && exit 0
            printf 'client\ndev tun\nremote vpn.example.invalid 1194\n<key>\nCLE-PRIVEE-FACTICE-42\n</key>\n' ;;
          op://Imarcom/VPN/username) printf 'jean,dupont' ;;
          op://Imarcom/VPN/password) printf '%s' 'Mdp,a\b:9' ;;
          *) echo "[ERROR] introuvable" >&2; exit 1 ;;
        esac ;;
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
SECRET='Mdp,a\b:9'; PROFILE_MARK="CLE-PRIVEE-FACTICE-42"
count_calls() { grep -c -- "$1" "$CALLS" || true; }
nmcli_calls() { grep -c -- "$1" "$NMCLI_LOG" || true; }

printf '%s\n' "== dépendances =="
# Lu dans un bash à part : le module chargé dans un sous-shell du test ferait
# croire à shellcheck que les variables du test y sont modifiées.
# shellcheck disable=SC2016  # développé par le bash lancé, pas ici
assert_eq "dépend de base et de 1password (lancé seul, 1password passe avant)" "base 1password" \
  "$(bash -c 'source "$1"; printf "%s" "$MODULE_DEPS"' _ "$MOD")"

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

printf '%s\n' "== formes échappées =="
assert_eq "pour l'éditeur : « \\ » puis « , »" 'Mdp\,a\\b:9' "$(bash -c 'source "$1"; _vpn_escape "$2"' _ "$MOD" "$SECRET")"
assert_eq "rendu de -g (relevé 0.3 : ab,c\\d)" 'ab\\,c\\d' "$(bash -c 'source "$1"; _vpn_shown "ab,c\d"' _ "$MOD")"
assert_eq "rendu de -g : « : » échappé" 'Mdp\\,a\\b\:9' "$(bash -c 'source "$1"; _vpn_shown "$2"' _ "$MOD" "$SECRET")"

# État « aucune connexion OpenVPN, session active » : l'ethernet et la WireGuard
# « Imarcom » restent, rien d'autre.
reset_vpn() {
  printf '1111-eth:ethernet\n2222-wg:vpn\n' >"$CONNS"
  printf 'org.freedesktop.NetworkManager.wireguard\n' >"$TEST_TMP/nm/2222-wg"
  rm -f "$TEST_TMP"/{import-refuse,import-noop,modify-refuse,edit-refuse,edit-noop,edit-alter,edit-interrupt,ovpn-refuse,ovpn-empty,perm}
  rm -rf "$VPN_CERT_DIR" "${XDG_RUNTIME_DIR:?}"/*
  touch "$TEST_TMP/session"
  : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; : >"$LOG_FILE"; : >"$NMCLI_LOG"
}
# new_uuid : UUID de la connexion OpenVPN créée (vide s'il n'y en a pas).
new_uuid() { grep ':vpn$' "$CONNS" | cut -d: -f1 | grep -vx 2222-wg; }
no_leftovers() {
  assert_eq "$1 : aucun fichier temporaire du profil" "" "$(ls -A "$XDG_RUNTIME_DIR")"
  assert_eq "$1 : aucun fichier extrait restant" "" "$(ls -A "$VPN_CERT_DIR" 2>/dev/null)"
  assert_eq "$1 : aucune connexion OpenVPN" "" "$(new_uuid)"
}

printf '%s\n' "== création depuis 1Password =="
reset_vpn
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
u=$(new_uuid)
assert_ok "une connexion OpenVPN créée" test -n "$u"
assert_contains "profil importé sous le nom de la connexion" "$(cat "$NMCLI_LOG")" "connection import type openvpn file $XDG_RUNTIME_DIR/"
assert_contains "fichier du profil privé (0600) à l'import" "$(cat "$NMCLI_LOG")" "import-file 600"
assert_eq "pas de démarrage automatique" "no" "$(cat "$TEST_TMP/nm/$u.autoconnect")"
assert_contains "identifiant échappé" "$(cat "$TEST_TMP/nm/$u.data")" 'username = jean\,dupont'
assert_contains "mot de passe gardé par NetworkManager (password-flags 0)" "$(cat "$TEST_TMP/nm/$u.data")" "password-flags = 0"
assert_eq "secret enregistré tel quel" "$SECRET" "$(cat "$TEST_TMP/nm/$u.secret")"
assert_ok "module_check → déjà fait" mcall module_check
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_eq "WireGuard « Imarcom » intacte" "org.freedesktop.NetworkManager.wireguard" "$(cat "$TEST_TMP/nm/2222-wg")"
assert_contains "WireGuard toujours listée" "$(cat "$CONNS")" "2222-wg:vpn"
assert_not_contains "WireGuard jamais modifiée" "$(cat "$NMCLI_LOG")" "modify uuid 2222-wg"
assert_not_contains "mot de passe absent de la sortie" "$out" "$SECRET"
assert_not_contains "mot de passe absent du journal" "$(cat "$LOG_FILE")" "$SECRET"
assert_not_contains "mot de passe absent des arguments de nmcli" "$(cat "$NMCLI_LOG")" "a\\b"
assert_not_contains "profil absent de la sortie" "$out" "$PROFILE_MARK"
assert_not_contains "profil absent du journal" "$(cat "$LOG_FILE")" "$PROFILE_MARK"
assert_not_contains "profil absent des arguments de nmcli" "$(cat "$NMCLI_LOG")" "$PROFILE_MARK"
assert_contains "éditeur tracé sans le mot de passe" "$(cat "$LOG_FILE")" "(mot de passe par l'entrée standard)"
assert_eq "aucun fichier temporaire du profil" "" "$(ls -A "$XDG_RUNTIME_DIR")"
assert_eq "fichiers extraits gardés (connexion réussie)" 4 "$(find "$VPN_CERT_DIR" -name 'Imarcom-*.pem' | wc -l)"

printf '%s\n' "== connexion OpenVPN existante =="
: >"$CALLS"; : >"$NMCLI_LOG"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_eq "aucune modification" 0 "$(nmcli_calls 'modify')"
assert_eq "aucun import" 0 "$(nmcli_calls 'import')"

printf '%s\n' "== sans session 1Password =="
reset_vpn; rm -f "$TEST_TMP/session"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape d'import" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"
assert_eq "aucun import" 0 "$(nmcli_calls 'import')"
assert_fail "module_check → à faire" mcall module_check

printf '%s\n' "== sans autorisation (session distante) =="
reset_vpn; printf 'auth' >"$TEST_TMP/perm"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape d'import" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_eq "aucun import" 0 "$(nmcli_calls 'import')"

printf '%s\n' "== profil absent de l'élément =="
reset_vpn; touch "$TEST_TMP/ovpn-refuse"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape d'import" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"
assert_contains "avertissement qui nomme la référence" "$out" "op://Imarcom/VPN/jpellerin.ovpn"
assert_not_contains "aucune erreur de op à l'écran" "$out" "[ERROR]"
assert_not_contains "aucun échec annoncé" "$out" "✖"
assert_eq "mot de passe jamais lu" 0 "$(count_calls 'op read op://Imarcom/VPN/password')"
assert_eq "aucun import" 0 "$(nmcli_calls 'import')"
no_leftovers "profil absent"

printf '%s\n' "== profil vide =="
reset_vpn; touch "$TEST_TMP/ovpn-empty"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape d'import" "$(cat "$MANUAL_STEPS_FILE")" "$IMPORT"
assert_eq "mot de passe jamais lu" 0 "$(count_calls 'op read op://Imarcom/VPN/password')"
no_leftovers "profil vide"

# fail_case <drapeau> <étape attendue dans le message>
fail_case() {
  reset_vpn; touch "$TEST_TMP/$1"
  out=$(mcall module_configure 2>&1); rc=$?
  assert_eq "$1 : module_configure échoue" 1 "$rc"
  assert_contains "$1 : échec nommé" "$out" "Création de la connexion VPN « Imarcom » impossible : $2"
  assert_eq "$1 : aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"
  assert_not_contains "$1 : mot de passe absent de la sortie" "$out" "$SECRET"
  no_leftovers "$1"
  assert_fail "$1 : module_check → à faire" mcall module_check
}
printf '%s\n' "== création en échec =="
fail_case import-refuse "import du profil"
fail_case import-noop "l'import n'a pas créé une et une seule connexion OpenVPN"
fail_case modify-refuse "identifiant et réglages"
fail_case edit-refuse "enregistrement du mot de passe"
fail_case edit-noop "contrôle du mot de passe enregistré"
fail_case edit-alter "contrôle du mot de passe enregistré"

printf '%s\n' "== interruption pendant la création =="
reset_vpn; touch "$TEST_TMP/edit-interrupt"
mcall module_configure >/dev/null 2>&1; rc=$?
assert_eq "module interrompu (SIGINT)" 130 "$rc"
no_leftovers "interruption"
assert_fail "module_check → à faire" mcall module_check
assert_contains "WireGuard « Imarcom » intacte" "$(cat "$CONNS")" "2222-wg:vpn"

test_done
