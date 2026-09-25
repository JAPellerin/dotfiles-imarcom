#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/63-spotify.sh — client Spotify depuis le dépôt apt de Spotify,
# connexion guidée par code QR.
#   https://www.spotify.com/download/linux/
#
# Même dépôt et même clé que la doc, déclarés par le socle en deb822 (clé liée
# au seul dépôt par Signed-By) plutôt que dans trusted.gpg.d et un .list (design D1).
# Le nom du fichier de clé porte son identifiant : Spotify le change quand il
# renouvelle sa clé, la constante est alors à reporter.
# Le paquet déclare lui-même son dépôt dans spotify.list, sauf si ce fichier
# existe : il est posé avant le paquet, sans entrée (D3 — même piège que Chrome
# et Claude Desktop, mais sans fichier de réglage).
# Connexion guidée sans secret (D5 à D8) : Spotify ouvert, consigne (code QR à
# scanner avec le téléphone), attente du signe de connexion dans ses préférences ;
# « connecté » fait partie du « déjà fait ». Aucune lecture dans 1Password.
# Voir openspec/specs/module-spotify/spec.md,
# openspec/changes/archive/2026-09-24-spotify/design.md (D1 à D4) et
# openspec/changes/spotify-connexion/design.md (D5 à D8).
MODULE_NAME="spotify"
MODULE_DESC="Spotify (dépôt apt Spotify) ; connexion guidée par code QR"
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
# Préférences du client, où il note la connexion (D5) ; surchargeable (tests).
SPOTIFY_PREFS="${SPOTIFY_PREFS:-${XDG_CONFIG_HOME:-$HOME/.config}/spotify/prefs}"

# _spotify_logged_in : vrai si le client est connecté (D5) — ligne
# autologin.username non vide dans ses préférences ; le client la retire à la
# déconnexion (autologin.canonical_username, lui, reste : pas un signe). Fichier
# absent → faux, sans message (grep -s). grep lit le fichier, sans tube.
_spotify_logged_in() {
  grep -Eqs '^autologin\.username="?[^"]+' -- "$SPOTIFY_PREFS"
}

# Déjà fait = paquet installé, spotify.list en place avec le contenu versionné
# (le paquet le relit à chaque mise à jour) (D3), et client connecté (D5). Lu
# sans sudo, réseau ni 1Password.
module_check() {
  pkg_installed "$SPOTIFY_PKG" || return 1
  cmp -s -- "$DOTFILES_DIR/$SPOTIFY_LIST_SRC" "$SPOTIFY_LIST" || return 1
  _spotify_logged_in
}

# spotify.list d'abord, puis dépôt, puis paquet (D1, D3). Installation seule :
# la connexion se fait dans module_configure, par le parcours guidé (D6, D7).
module_install() {
  install_system_file "$SPOTIFY_LIST_SRC" "$SPOTIFY_LIST" || return 1
  apt_add_repo spotify "$SPOTIFY_KEY_URL" "$SPOTIFY_REPO_URL" "$SPOTIFY_SUITE" "$SPOTIFY_COMPONENT" || return 1
  apt_install "$SPOTIFY_PKG"
}

# Connexion guidée, sans secret (D6) : déjà connecté → rien ; sinon Spotify
# ouvert et consigne. Consigne sans libellé d'interface (le client suit la
# langue du système) : le code QR est désigné par sa place à l'écran. Jamais
# d'échec : l'étape manuelle est déclarée si le parcours n'aboutit pas. Réglages
# du client hors périmètre.
module_configure() {
  guided_login "Spotify" _spotify_logged_in "$SPOTIFY_LOGIN_MANUAL" \
    --open open_detached spotify ";" \
    -- "Dans Spotify, le plus rapide : le code QR, à droite de l'écran de connexion." \
       "Le scanner avec l'appareil photo du téléphone, puis confirmer la connexion sur le téléphone."
}
