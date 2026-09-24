#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/63-spotify.sh — client Spotify depuis le dépôt apt de Spotify,
# connexion signalée au résumé.
#   https://www.spotify.com/download/linux/
#
# Même dépôt et même clé que la doc, déclarés par le socle en deb822 (clé liée
# au seul dépôt par Signed-By) plutôt que dans trusted.gpg.d et un .list (design D1).
# Le nom du fichier de clé porte son identifiant : Spotify le change quand il
# renouvelle sa clé, la constante est alors à reporter.
# Le paquet déclare lui-même son dépôt dans spotify.list, sauf si ce fichier
# existe : il est posé avant le paquet, sans entrée (D3 — même piège que Chrome
# et Claude Desktop, mais sans fichier de réglage).
# Voir openspec/specs/module-spotify/spec.md et openspec/changes/archive/2026-09-24-spotify/design.md.
MODULE_NAME="spotify"
MODULE_DESC="Spotify (dépôt apt Spotify)"
MODULE_GROUP="apps"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

SPOTIFY_KEY_URL="https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc"
SPOTIFY_REPO_URL="https://repository.spotify.com"
SPOTIFY_SUITE="stable"
SPOTIFY_COMPONENT="non-free"
SPOTIFY_PKG="spotify-client"
# Racine surchargeable pour les tests.
SPOTIFY_ETC="${SPOTIFY_ETC:-}"
SPOTIFY_LIST_SRC="config/spotify/spotify.list"
SPOTIFY_LIST="$SPOTIFY_ETC/etc/apt/sources.list.d/spotify.list"
SPOTIFY_LOGIN_MANUAL="Ouvrir Spotify (menu des applications) et se connecter."

# Déjà fait = paquet installé et spotify.list en place avec le contenu versionné
# (le paquet le relit à chaque mise à jour) (D2, D3). Lu sans sudo ni réseau.
module_check() {
  pkg_installed "$SPOTIFY_PKG" || return 1
  cmp -s -- "$DOTFILES_DIR/$SPOTIFY_LIST_SRC" "$SPOTIFY_LIST"
}

# spotify.list d'abord, puis dépôt, puis paquet (D1, D3). L'étape de connexion
# est déclarée ici et non dans module_configure : le runner lance chaque
# fonction dans son propre sous-shell, une variable « paquet absent avant »
# serait perdue en chemin (D2).
module_install() {
  local fresh=0
  pkg_installed "$SPOTIFY_PKG" || fresh=1
  install_system_file "$SPOTIFY_LIST_SRC" "$SPOTIFY_LIST" || return 1
  apt_add_repo spotify "$SPOTIFY_KEY_URL" "$SPOTIFY_REPO_URL" "$SPOTIFY_SUITE" "$SPOTIFY_COMPONENT" || return 1
  apt_install "$SPOTIFY_PKG" || return 1
  if (( fresh == 1 )); then
    manual_step "$SPOTIFY_LOGIN_MANUAL"
  fi
}

# Rien à configurer : réglages et compte hors périmètre.
module_configure() {
  :
}
