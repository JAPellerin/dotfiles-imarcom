#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/65-vpn.sh — OpenVPN et son greffon NetworkManager pour GNOME, depuis
# les dépôts d'Ubuntu ; la connexion « Imarcom » est créée depuis le profil et les
# identifiants de 1Password, puis s'active depuis le menu système.
#   https://packages.ubuntu.com/resolute/network-manager-openvpn-gnome
#
# Le module reste « à faire » tant qu'aucune connexion VPN OpenVPN n'existe dans
# NetworkManager (D2). Sans connexion, il importe le profil joint à l'élément
# 1Password du VPN par nmcli, depuis la session graphique (polkit, sans sudo),
# règle l'identifiant et le mot de passe (gardé par NetworkManager dans sa
# configuration système), sans démarrage automatique (D4 à D7). Profil et mot de
# passe jamais affichés ni journalisés ; jamais de connexion à moitié créée, même
# après une interruption (D6). Une connexion OpenVPN existante n'est jamais
# modifiée (D8).
# Voir openspec/specs/module-vpn/spec.md,
# openspec/changes/archive/2026-09-24-vpn/design.md (D1 à D3) et
# openspec/changes/vpn-profil/design.md (D4 à D9).
MODULE_NAME="vpn"
MODULE_DESC="OpenVPN et son greffon NetworkManager ; profil Imarcom depuis 1Password"
MODULE_GROUP="apps"
MODULE_DEPS="base 1password"
MODULE_NEEDS_GUI=1

VPN_PACKAGES=(openvpn network-manager-openvpn-gnome)
VPN_IMPORT_MANUAL="Importer le profil VPN de l'équipe TI : Paramètres > Réseau > VPN > + > Importer depuis un fichier (.ovpn)."
VPN_OP_ITEM="op://Imarcom/VPN"
VPN_OVPN_REF="$VPN_OP_ITEM/jpellerin.ovpn"
VPN_USER_REF="$VPN_OP_ITEM/username"
VPN_PASSWORD_REF="$VPN_OP_ITEM/password"
# Nom de la connexion : celui du fichier importé (D5).
VPN_CONNECTION_NAME="Imarcom"
# Où le greffon extrait certificats et clé du profil (relevé en VM le 25 sept
# 2026) ; surchargeable (tests).
VPN_CERT_DIR="${VPN_CERT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/networkmanagement/certificates/nm-openvpn}"
VPN_PERMISSION="org.freedesktop.NetworkManager.settings.modify.system:yes"

# _vpn_openvpn_uuids : UUID des connexions VPN OpenVPN, un par ligne, triés.
# Lecture seule, sans sudo ni réseau ; nmcli absent ou en erreur → échec.
# Connexions désignées par leur UUID : un nom peut contenir « : », séparateur de
# la sortie -t. Le nmcli de la boucle lit /dev/null, pour ne jamais consommer la
# liste que lit `read`.
_vpn_openvpn_uuids() {
  local list uuid type
  list=$(nmcli -t -f UUID,TYPE connection show 2>/dev/null) || return 1
  while IFS=: read -r uuid type; do
    [[ $type == vpn ]] || continue
    # « if » et non « && » : sous pipefail, une dernière connexion non OpenVPN
    # ferait échouer la boucle, donc le tube, donc la liste.
    if [[ $(nmcli -g vpn.service-type connection show uuid "$uuid" </dev/null 2>/dev/null) == *openvpn* ]]; then
      printf '%s\n' "$uuid"
    fi
  done <<<"$list" | sort
}

# vpn_profile_present : vrai si une connexion VPN OpenVPN existe dans
# NetworkManager ; nmcli absent ou en erreur → faux (aucun profil constaté).
vpn_profile_present() {
  local uuids
  uuids=$(_vpn_openvpn_uuids) || return 1
  [[ -n $uuids ]]
}

# _vpn_escape <valeur> : valeur pour nmcli (+vpn.data, et éditeur pour
# vpn.secrets) — « \ » puis « , », séparateurs du format, précédés d'un « \ ».
_vpn_escape() {
  local v=${1//\\/\\\\}
  printf '%s' "${v//,/\\,}"
}

# _vpn_shown <valeur> : forme sous laquelle `nmcli -g` rend une valeur
# enregistrée dans vpn.data ou vpn.secrets (relevé 0.3) : « , » précédé d'un
# « \ » (format de la valeur, qui n'échappe pas « \ »), puis chaque « \ » doublé
# et chaque « : » précédé d'un « \ » (format de -g). Le contrôle compare les
# formes échappées, calculées du côté connu (D6).
_vpn_shown() {
  local v=${1//,/\\,}
  v=${v//\\/\\\\}
  printf '%s' "${v//:/\\:}"
}

# Connexion en cours de création, retirée par _vpn_abandon si le module échoue ou
# s'interrompt avant le contrôle (D6) ; vidée une fois le contrôle réussi.
_VPN_PENDING_UUID=""

# _vpn_abandon : retire la connexion en cours de création et les fichiers que le
# greffon en a extraits (delete les laisse, relevé 0.3). Enregistré par
# add_cleanup dès l'UUID connu : s'exécute aussi sur Ctrl-C. Sans connexion en
# cours, ne fait rien.
_vpn_abandon() {
  [[ -n ${_VPN_PENDING_UUID:-} ]] || return 0
  nmcli connection delete uuid "$_VPN_PENDING_UUID" >>"$LOG_FILE" 2>&1 </dev/null || true
  rm -f -- "$VPN_CERT_DIR/$VPN_CONNECTION_NAME"-*.pem
  _VPN_PENDING_UUID=""
}

# _vpn_fail <étape> : connexion en cours et fichiers extraits retirés, échec nommé.
_vpn_fail() {
  _vpn_abandon
  rm -f -- "$VPN_CERT_DIR/$VPN_CONNECTION_NAME"-*.pem
  log_error "Création de la connexion VPN « $VPN_CONNECTION_NAME » impossible : $1"
  return 1
}

# _vpn_manual <avertissement> : empêchement avant l'import → étape manuelle, sans échec.
_vpn_manual() {
  log_warn "$1"
  manual_step "$VPN_IMPORT_MANUAL"
  return 0
}

# _vpn_import : crée la connexion « Imarcom » (D4 à D7). Rend 0 si elle est créée
# ou si une étape manuelle a été déclarée, 1 sur un échec de création (nommé).
_vpn_import() {
  local perms dir file user password before after uuid data secrets
  # 1. Session 1Password.
  op_session_active || { _vpn_manual "VPN : aucune session 1Password, le profil ne peut pas être lu."; return; }
  # 2. Droit de modifier les connexions système (polkit) : par SSH, « auth ».
  perms=$(nmcli -t -f PERMISSION,VALUE general permissions 2>/dev/null) || perms=""
  [[ $'\n'$perms$'\n' == *$'\n'"$VPN_PERMISSION"$'\n'* ]] \
    || { _vpn_manual "VPN : la session ne permet pas de créer une connexion système (session graphique requise)."; return; }
  # 3. Profil (clé privée) : fichier temporaire privé, nettoyage enregistré avant
  #    l'écriture, jamais par $(…) ni par run (D5).
  if [[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR && -w $XDG_RUNTIME_DIR ]]; then
    dir=$(mktemp -d -p "$XDG_RUNTIME_DIR" dotfiles-vpn.XXXXXX) || return 1
  else
    dir=$(mktemp -d -t dotfiles-vpn.XXXXXX) || return 1
  fi
  add_cleanup "rm -rf -- '$dir'"
  chmod 700 -- "$dir" || return 1
  file="$dir/$VPN_CONNECTION_NAME.ovpn"
  if ! (umask 077; op_read "$VPN_OVPN_REF" >"$file" 2>>"$LOG_FILE"); then
    _vpn_manual "VPN : profil illisible dans 1Password (« $VPN_OVPN_REF »)."
    return
  fi
  if ! grep -q '^client' -- "$file" || ! grep -q '^remote ' -- "$file"; then
    _vpn_manual "VPN : « $VPN_OVPN_REF » n'est pas un profil OpenVPN (vide ou sans « client » / « remote »)."
    return
  fi
  # 4. Identifiant et mot de passe, dans des variables.
  if ! user=$(op_read "$VPN_USER_REF" 2>>"$LOG_FILE") || [[ -z $user ]]; then
    _vpn_manual "VPN : identifiant illisible dans 1Password (« $VPN_USER_REF »)."
    return
  fi
  if ! password=$(op_read "$VPN_PASSWORD_REF" 2>>"$LOG_FILE") || [[ -z $password ]]; then
    _vpn_manual "VPN : mot de passe illisible dans 1Password (« $VPN_PASSWORD_REF »)."
    return
  fi
  # 5. Import. UUID par différence des listes avant et après : la sortie de
  #    l'import part au journal et suit la langue du système ; un nom peut exister
  #    deux fois (D6).
  before=$(_vpn_openvpn_uuids) || { unset password; _vpn_fail "liste des connexions illisible"; return; }
  if ! run nmcli connection import type openvpn file "$file"; then
    unset password; _vpn_fail "import du profil"; return
  fi
  after=$(_vpn_openvpn_uuids) || { unset password; _vpn_fail "liste des connexions illisible après l'import"; return; }
  uuid=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep -v '^$')
  if [[ -z $uuid || $uuid == *$'\n'* ]]; then
    unset password; _vpn_fail "l'import n'a pas créé une et une seule connexion OpenVPN"; return
  fi
  _VPN_PENDING_UUID=$uuid
  add_cleanup _vpn_abandon
  # Identifiant et réglages avant l'éditeur : avec autoconnect à yes, l'éditeur
  # demanderait une confirmation au « save ».
  if ! run nmcli connection modify uuid "$uuid" connection.autoconnect no \
       +vpn.data "username=$(_vpn_escape "$user")" +vpn.data password-flags=0; then
    unset password; _vpn_fail "identifiant et réglages"; return
  fi
  # Mot de passe par l'entrée standard de l'éditeur, jamais en argument ; sortie
  # vers /dev/null : l'éditeur répète la commande reçue, mot de passe compris.
  printf '[%s] $ nmcli connection edit uuid %s (mot de passe par l'"'"'entrée standard)\n' \
    "$(date +%H:%M:%S)" "$uuid" >>"$LOG_FILE"
  if ! printf 'set vpn.secrets password = %s\nsave\nquit\n' "$(_vpn_escape "$password")" \
       | nmcli connection edit uuid "$uuid" >/dev/null 2>&1; then
    unset password; _vpn_fail "enregistrement du mot de passe"; return
  fi
  # Contrôle, rien d'affiché : formes échappées comparées (D6).
  data=$(nmcli -g vpn.data connection show uuid "$uuid" 2>>"$LOG_FILE" </dev/null) || data=""
  secrets=$(nmcli --show-secrets -g vpn.secrets connection show uuid "$uuid" 2>/dev/null </dev/null) || secrets=""
  if [[ $data != *"username = $(_vpn_shown "$user")"* || $data != *"password-flags = 0"* ]]; then
    unset password secrets; _vpn_fail "contrôle de l'identifiant et des réglages"; return
  fi
  if [[ $secrets != "password = $(_vpn_shown "$password")" ]]; then
    unset password secrets; _vpn_fail "contrôle du mot de passe enregistré"; return
  fi
  unset password secrets
  _VPN_PENDING_UUID=""
  log_ok "Connexion VPN « $VPN_CONNECTION_NAME » créée (inactive : l'activer depuis le menu système)."
}

# Déjà fait = paquets installés et profil OpenVPN importé (D2 : sur un bureau
# standard les paquets sont déjà là, le profil est le vrai état attendu).
module_check() {
  local pkg
  for pkg in "${VPN_PACKAGES[@]}"; do
    pkg_installed "$pkg" || return 1
  done
  vpn_profile_present
}

# Seuls les paquets manquants passent à apt (D1) ; network-manager-openvpn-gnome
# tire network-manager-openvpn.
module_install() {
  apt_install "${VPN_PACKAGES[@]}"
}

# Constat refait ici (sous-shells du runner) : une connexion OpenVPN existe → rien,
# elle n'est jamais modifiée (D8) ; sinon création depuis 1Password (D4 à D7), ou
# étape d'import si elle est empêchée. Échec seulement si la création échoue.
module_configure() {
  vpn_profile_present && return 0
  _vpn_import
}
