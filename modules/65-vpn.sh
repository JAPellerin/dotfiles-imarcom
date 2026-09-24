#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/65-vpn.sh — OpenVPN et son greffon NetworkManager pour GNOME, depuis
# les dépôts d'Ubuntu ; les connexions VPN se gèrent dans Paramètres > Réseau > VPN.
#   https://packages.ubuntu.com/resolute/network-manager-openvpn-gnome
#
# Configuration reportée (décision de l'utilisateur, 23 sept 2026) : le profil et
# la méthode de connexion fournis par l'équipe TI restent à retrouver ; l'import
# du profil est une étape manuelle, et le module reste « à faire » tant qu'aucune
# connexion VPN OpenVPN n'existe dans NetworkManager (D2).
# Voir openspec/changes/vpn/design.md.
MODULE_NAME="vpn"
MODULE_DESC="OpenVPN et son greffon NetworkManager ; import du profil (manuel)"
MODULE_GROUP="apps"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

VPN_PACKAGES=(openvpn network-manager-openvpn-gnome)
VPN_IMPORT_MANUAL="Importer le profil VPN de l'équipe TI : Paramètres > Réseau > VPN > + > Importer depuis un fichier (.ovpn)."

# vpn_profile_present : vrai si une connexion VPN OpenVPN existe dans
# NetworkManager. Lecture seule, sans sudo ni réseau ; nmcli absent ou en
# erreur → faux (aucun profil constaté). Connexions désignées par leur UUID :
# un nom peut contenir « : », séparateur de la sortie -t. Le nmcli de la boucle
# lit /dev/null, pour ne jamais consommer la liste que lit `read`.
vpn_profile_present() {
  local list uuid type
  list=$(nmcli -t -f UUID,TYPE connection show 2>/dev/null) || return 1
  while IFS=: read -r uuid type; do
    [[ $type == vpn ]] || continue
    [[ $(nmcli -g vpn.service-type connection show uuid "$uuid" </dev/null 2>/dev/null) == *openvpn* ]] && return 0
  done <<<"$list"
  return 1
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

# Constat refait ici (sous-shells du runner) : aucun profil → étape d'import,
# sans échec. Le module ne crée ni ne modifie aucune connexion.
module_configure() {
  vpn_profile_present || manual_step "$VPN_IMPORT_MANUAL"
  return 0
}
