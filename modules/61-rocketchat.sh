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
# Voir openspec/changes/rocketchat/design.md.
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
ROCKETCHAT_LOGIN_MANUAL="Ouvrir Rocket.Chat (menu des applications) et se connecter à rocketchat.imarcom.net."

# Déjà fait = paquet installé et liste de serveurs identique à celle du dépôt
# (D4). Sans sudo ni réseau : l'API GitHub n'est jamais appelée ici.
module_check() {
  pkg_installed "$ROCKETCHAT_PKG" || return 1
  cmp -s -- "$DOTFILES_DIR/$ROCKETCHAT_SERVERS_SRC" "$ROCKETCHAT_SERVERS"
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
  apt_install_deb_url "$url" "$ROCKETCHAT_PKG" || return 1
  manual_step "$ROCKETCHAT_LOGIN_MANUAL"
}

# Liste de serveurs par défaut (D2), après le paquet : un fichier absent ou
# différent est réécrit ; aucun paquet ne le déclare, dpkg le laisse en place.
module_configure() {
  install_system_file "$ROCKETCHAT_SERVERS_SRC" "$ROCKETCHAT_SERVERS"
}
