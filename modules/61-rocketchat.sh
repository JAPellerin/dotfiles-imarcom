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
# Connexion guidée par 1Password (D7 à D10) : identifiant affiché, mot de passe
# copié dans le presse-papiers, client ouvert, attente du signe de connexion dans
# ~/.config/Rocket.Chat/config.json ; « connecté » fait partie du « déjà fait ».
# Voir openspec/specs/module-rocketchat/spec.md,
# openspec/changes/archive/2026-09-24-rocketchat/design.md (D1 à D6) et
# openspec/changes/rocketchat-connexion/design.md (D7 à D10).
MODULE_NAME="rocketchat"
MODULE_DESC="Rocket.Chat (.deb officiel) ; serveur rocketchat.imarcom.net pré-configuré ; connexion guidée par 1Password"
MODULE_GROUP="apps"
MODULE_DEPS="base 1password"
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
# Commande du lanceur du paquet : aucune commande dans le PATH (relevé en VM le
# 25 sept 2026) ; préfixée par la racine, comme les fichiers ci-dessus (D8).
ROCKETCHAT_BIN="$ROCKETCHAT_ROOT/opt/Rocket.Chat/rocketchat-desktop"
# Configuration du client, où il note la connexion (D7) ; surchargeable (tests).
ROCKETCHAT_CONFIG="${ROCKETCHAT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/Rocket.Chat/config.json}"
ROCKETCHAT_USER_REF="op://Imarcom/RocketChat/username"
ROCKETCHAT_PASSWORD_REF="op://Imarcom/RocketChat/password"

# _rocketchat_logged_in : vrai si le client est connecté au serveur de
# l'entreprise (D7). URL attendue lue dans la liste de serveurs du dépôt ; « / »
# final ignoré des deux côtés (le client l'ajoute). Sans sudo, réseau ni 1Password ;
# fichier absent, JSON illisible, .servers absent ou url nulle → faux.
_rocketchat_logged_in() {
  local url
  url=$(jq -r 'first(.[])' "$DOTFILES_DIR/$ROCKETCHAT_SERVERS_SRC" 2>/dev/null) || return 1
  url=${url%/}
  [[ -n $url ]] || return 1
  jq -e --arg url "$url" \
    'any(.servers[]?; ((.url // "") | rtrimstr("/")) == $url and .userLoggedIn == true)' \
    "$ROCKETCHAT_CONFIG" >/dev/null 2>&1
}

# Déjà fait = paquet installé, liste de serveurs et profil AppArmor identiques à
# ceux du dépôt (D4), et client connecté au serveur de l'entreprise (D7). Sans
# sudo, réseau ni 1Password : l'API GitHub n'est jamais appelée ici.
# Le chargement du profil n'est pas lisible sans root : le fichier en tient lieu,
# AppArmor charge /etc/apparmor.d/ à chaque démarrage.
module_check() {
  pkg_installed "$ROCKETCHAT_PKG" || return 1
  cmp -s -- "$DOTFILES_DIR/$ROCKETCHAT_SERVERS_SRC" "$ROCKETCHAT_SERVERS" || return 1
  cmp -s -- "$DOTFILES_DIR/$ROCKETCHAT_APPARMOR_SRC" "$ROCKETCHAT_APPARMOR" || return 1
  _rocketchat_logged_in
}

# Paquet présent → aucun appel à GitHub ni téléchargement ; une mise à jour est
# proposée par le client lui-même (D1). Installation seule : la connexion se
# fait dans module_configure, par le parcours guidé (D8, D9).
module_install() {
  local url
  if pkg_installed "$ROCKETCHAT_PKG"; then
    log_ok "Paquet déjà installé : $ROCKETCHAT_PKG"
    return 0
  fi
  url=$(github_release_asset_url "$ROCKETCHAT_REPO" "$ROCKETCHAT_ASSET_PATTERN") || return 1
  log_info "Rocket.Chat : $url"
  apt_install_deb_url "$url" "$ROCKETCHAT_PKG"
}

# Liste de serveurs par défaut (D2), après le paquet : un fichier absent ou
# différent est réécrit ; aucun paquet ne le déclare, dpkg le laisse en place.
# Profil AppArmor (D6) : chargé seulement s'il vient d'être écrit ; retiré si le
# chargement échoue, pour que module_check ne tienne pas pour fait un profil
# jamais chargé.
# Puis connexion guidée (D8), dans tous les cas : déjà connecté → rien (ni 1Password
# ni fenêtre) ; sinon identifiant affiché, mot de passe dans le presse-papiers,
# client ouvert. Consigne sans libellé d'interface : le client suit la langue du
# système. Jamais d'échec : l'étape manuelle est déclarée si le parcours n'aboutit pas.
module_configure() {
  install_system_file "$ROCKETCHAT_SERVERS_SRC" "$ROCKETCHAT_SERVERS" || return 1
  if cmp -s -- "$DOTFILES_DIR/$ROCKETCHAT_APPARMOR_SRC" "$ROCKETCHAT_APPARMOR"; then
    log_ok "Profil AppArmor déjà à jour : $ROCKETCHAT_APPARMOR"
  else
    install_system_file "$ROCKETCHAT_APPARMOR_SRC" "$ROCKETCHAT_APPARMOR" || return 1
    if ! run_sudo apparmor_parser -r "$ROCKETCHAT_APPARMOR"; then
      log_error "Chargement du profil AppArmor impossible : $ROCKETCHAT_APPARMOR (retiré)"
      run_sudo rm -f -- "$ROCKETCHAT_APPARMOR"
      return 1
    fi
    log_ok "Profil AppArmor chargé : $ROCKETCHAT_APPARMOR"
  fi
  guided_login "Rocket.Chat" _rocketchat_logged_in "$ROCKETCHAT_LOGIN_MANUAL" \
    --user "$ROCKETCHAT_USER_REF" --secret "$ROCKETCHAT_PASSWORD_REF" \
    --open open_detached "$ROCKETCHAT_BIN" ";" \
    -- "Dans Rocket.Chat (rocketchat.imarcom.net) : saisir l'identifiant affiché ci-dessus dans le premier champ du formulaire." \
       "Mot de passe : le coller (Ctrl-V) dans le second champ, puis valider (Entrée)."
}
