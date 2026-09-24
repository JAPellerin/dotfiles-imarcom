#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/61-rocketchat.sh — client de bureau Rocket.Chat depuis le `.deb` le plus
# récent des releases GitHub de l'éditeur, serveur de l'entreprise pré-configuré.
#   https://github.com/RocketChat/Rocket.Chat.Electron/releases
#   https://github.com/RocketChat/Rocket.Chat.Electron#default-servers
#
# Pas de dépôt apt : le `.deb` passe par github_release_asset_url puis
# apt_install_deb_url (design D1). servers.json, lu au premier lancement tant
# qu'aucun serveur n'a été ajouté, saute l'écran « Connect to server » ; il est
# copié sous /opt/Rocket.Chat/resources/, que le client relit sans y toucher, et
# non dans ~/.config/Rocket.Chat/, où le client le supprime après lecture
# (loadUserServers dans src/servers/main.ts, relevé du 24 sept 2026) : un lien y
# disparaîtrait au premier lancement (D2).
# Profil AppArmor versionné (D6) : sans lui, Ubuntu 26.04 refuse au client les
# espaces de noms utilisateur et il plante au lancement ; le paquet n'installe pas
# le sien, et son postrm supprime /etc/apparmor.d/rocketchat-desktop à chaque
# mise à jour : le nôtre porte le nom du chemin du binaire.
#   https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces
# Voir openspec/specs/module-rocketchat/spec.md et openspec/changes/archive/2026-09-24-rocketchat/design.md.
MODULE_NAME="rocketchat"
MODULE_DESC="Rocket.Chat (.deb officiel) ; serveur rocketchat.imarcom.net pré-configuré"
MODULE_GROUP="apps"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

ROCKETCHAT_REPO="RocketChat/Rocket.Chat.Electron"
ROCKETCHAT_ASSET_PATTERN='-linux-amd64\.deb$'
ROCKETCHAT_PKG="rocketchat"
ROCKETCHAT_SERVERS_SRC="config/rocketchat/servers.json"
# Racine surchargeable (tests), comme CLAUDE_DESKTOP_ETC pour claude-desktop.
ROCKETCHAT_ROOT="${ROCKETCHAT_ROOT:-}"
ROCKETCHAT_SERVERS="$ROCKETCHAT_ROOT/opt/Rocket.Chat/resources/servers.json"
ROCKETCHAT_APPARMOR_SRC="config/rocketchat/apparmor-profile"
ROCKETCHAT_APPARMOR="$ROCKETCHAT_ROOT/etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin"
ROCKETCHAT_LOGIN_MANUAL="Ouvrir Rocket.Chat (menu des applications) et se connecter à rocketchat.imarcom.net."

# Déjà fait = paquet installé, liste de serveurs et profil AppArmor identiques à
# ceux du dépôt (D4). Sans sudo ni réseau : l'API GitHub n'est jamais appelée ici.
# Le chargement du profil n'est pas lisible sans root : le fichier en tient lieu,
# AppArmor charge /etc/apparmor.d/ à chaque démarrage.
module_check() {
  pkg_installed "$ROCKETCHAT_PKG" || return 1
  cmp -s -- "$DOTFILES_DIR/$ROCKETCHAT_SERVERS_SRC" "$ROCKETCHAT_SERVERS" || return 1
  cmp -s -- "$DOTFILES_DIR/$ROCKETCHAT_APPARMOR_SRC" "$ROCKETCHAT_APPARMOR"
}

# Paquet présent → aucun appel à GitHub ni téléchargement ; une mise à jour est
# proposée par le client lui-même (D1). L'étape de connexion est déclarée ici,
# après une installation réussie : le runner lance module_configure dans un autre
# sous-shell, une variable « paquet absent avant » y serait perdue (D3).
module_install() {
  local url
  if pkg_installed "$ROCKETCHAT_PKG"; then
    log_ok "Paquet déjà installé : $ROCKETCHAT_PKG"
    return 0
  fi
  url=$(github_release_asset_url "$ROCKETCHAT_REPO" "$ROCKETCHAT_ASSET_PATTERN") || return 1
  log_info "Rocket.Chat : $url"
  apt_install_deb_url "$url" "$ROCKETCHAT_PKG" || return 1
  manual_step "$ROCKETCHAT_LOGIN_MANUAL"
}

# Liste de serveurs par défaut (D2), après le paquet : un fichier absent ou
# différent est réécrit ; aucun paquet ne le déclare, dpkg le laisse en place.
# Profil AppArmor (D6) : chargé seulement s'il vient d'être écrit ; retiré si le
# chargement échoue, pour que module_check ne tienne pas pour fait un profil
# jamais chargé.
module_configure() {
  install_system_file "$ROCKETCHAT_SERVERS_SRC" "$ROCKETCHAT_SERVERS" || return 1
  cmp -s -- "$DOTFILES_DIR/$ROCKETCHAT_APPARMOR_SRC" "$ROCKETCHAT_APPARMOR" && {
    log_ok "Profil AppArmor déjà à jour : $ROCKETCHAT_APPARMOR"
    return 0
  }
  install_system_file "$ROCKETCHAT_APPARMOR_SRC" "$ROCKETCHAT_APPARMOR" || return 1
  if ! run_sudo apparmor_parser -r "$ROCKETCHAT_APPARMOR"; then
    log_error "Chargement du profil AppArmor impossible : $ROCKETCHAT_APPARMOR (retiré)"
    run_sudo rm -f -- "$ROCKETCHAT_APPARMOR"
    return 1
  fi
  log_ok "Profil AppArmor chargé : $ROCKETCHAT_APPARMOR"
}
