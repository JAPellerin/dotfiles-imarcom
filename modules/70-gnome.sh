#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/70-gnome.sh — réglages de base du bureau GNOME (clavier, thème sombre,
# fond d'écran, dock, confidentialité) déployés comme VALEURS PAR DÉFAUT du
# système, dans la base dconf du système : ce que l'utilisateur règle lui-même
# garde la priorité, et une relance ne l'écrase pas (décision de l'utilisateur).
#
# Suit la doc officielle :
#   https://help.gnome.org/admin/system-admin-guide/stable/dconf-profiles.html
#   https://help.gnome.org/admin/system-admin-guide/stable/dconf-custom-defaults.html
# Deux fichiers versionnés, copiés par install_system_file : le profil dconf de
# l'utilisateur (absent sur Ubuntu 26.04 : sans lui, la base du système n'est pas
# lue) et les réglages, au format de `dconf dump` ; puis `dconf update`, seulement
# si quelque chose a changé (D1 à D3). Aucun réglage n'est verrouillé. Seule
# exception à la base du système : le dock, qu'Ubuntu écrit dans la base de
# l'utilisateur dès la première connexion ; il y est recopié tant qu'il est encore
# celui d'Ubuntu, jamais une fois modifié par l'utilisateur (D8).
# Voir openspec/changes/gnome/specs/module-gnome/spec.md et openspec/changes/gnome/design.md.
MODULE_NAME="gnome"
MODULE_DESC="bureau GNOME : clavier ; thème sombre ; fond ; dock ; confidentialité (valeurs par défaut du système)"
MODULE_GROUP="bureau"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

GNOME_PROFILE_SRC="config/gnome/dconf-profile"
GNOME_KEYFILE_SRC="config/gnome/reglages.dconf"
# Racine de /etc ; surchargeable (tests).
GNOME_ETC="${GNOME_ETC:-/etc}"
GNOME_PROFILE="$GNOME_ETC/dconf/profile/user"
GNOME_KEYFILE="$GNOME_ETC/dconf/db/local.d/00-dotfiles"
GNOME_DB="$GNOME_ETC/dconf/db/local"
GNOME_DOCK_KEY="/org/gnome/shell/favorite-apps"
# Dock écrit par Ubuntu 26.04 à la première connexion (relevé sur le snapshot
# vierge de la VM, 30 sept 2026) : tant qu'il vaut ceci, il est remplacé (D8).
GNOME_DOCK_UBUNTU="['firefox_firefox.desktop', 'org.gnome.Nautilus.desktop', 'snap-store_snap-store.desktop', 'org.gnome.Yelp.desktop', 'org.gnome.Ptyxis.desktop']"

# _gnome_same <source du dépôt> <cible> : cible identique au fichier du dépôt.
_gnome_same() { cmp -s -- "$DOTFILES_DIR/$1" "$2" 2>/dev/null; }

# _gnome_db_fresh : base compilée présente et pas plus ancienne que les réglages (D3).
_gnome_db_fresh() { [[ -f $GNOME_DB ]] && ! [[ $GNOME_KEYFILE -nt $GNOME_DB ]]; }

# _gnome_dock_ubuntu : le dock en vigueur est encore celui d'Ubuntu (D8).
_gnome_dock_ubuntu() { [[ $(dconf read "$GNOME_DOCK_KEY" 2>/dev/null) == "$GNOME_DOCK_UBUNTU" ]]; }

# _gnome_dock_repo : liste du dock du fichier de réglages du dépôt.
_gnome_dock_repo() { sed -n 's/^favorite-apps=//p' "$DOTFILES_DIR/$GNOME_KEYFILE_SRC"; }

# Déjà fait = dconf-cli installé, profil et réglages identiques au dépôt, base
# recompilée depuis, dock qui n'est plus celui d'Ubuntu (D5, D8). Les retouches
# de l'utilisateur ne rendent pas le module « à faire ».
module_check() {
  pkg_installed dconf-cli || return 1
  _gnome_same "$GNOME_PROFILE_SRC" "$GNOME_PROFILE" || return 1
  _gnome_same "$GNOME_KEYFILE_SRC" "$GNOME_KEYFILE" || return 1
  _gnome_db_fresh || return 1
  ! _gnome_dock_ubuntu
}

# dconf update en dépend ; sans effet s'il est déjà là (D6).
module_install() {
  apt_install dconf-cli
}

# Profil (D2 : un profil différent n'est jamais écrasé), réglages, puis
# recompilation seulement si l'un a changé ou si la base n'est pas fraîche (D3) ;
# enfin le dock, s'il est encore celui d'Ubuntu (D8).
module_configure() {
  local changed=0
  if [[ -e $GNOME_PROFILE ]] && ! _gnome_same "$GNOME_PROFILE_SRC" "$GNOME_PROFILE"; then
    log_error "Profil dconf existant et différent : $GNOME_PROFILE (laissé intact ; le fusionner à la main avec $GNOME_PROFILE_SRC)."
    return 1
  fi
  _gnome_same "$GNOME_PROFILE_SRC" "$GNOME_PROFILE" || changed=1
  install_system_file "$GNOME_PROFILE_SRC" "$GNOME_PROFILE" || return 1
  _gnome_same "$GNOME_KEYFILE_SRC" "$GNOME_KEYFILE" || changed=1
  install_system_file "$GNOME_KEYFILE_SRC" "$GNOME_KEYFILE" || return 1
  if (( changed )) || ! _gnome_db_fresh; then
    run_sudo dconf update || { log_error "dconf update a échoué (syntaxe de $GNOME_KEYFILE_SRC ?) : voir le journal."; return 1; }
    log_ok "Base dconf du système recompilée : les réglages de base s'appliquent à la prochaine session (valeurs par défaut)."
  else
    log_ok "Réglages de base du bureau déjà en place."
  fi
  if _gnome_dock_ubuntu; then
    run dconf write "$GNOME_DOCK_KEY" "$(_gnome_dock_repo)" || { log_error "Écriture du dock échouée : voir le journal."; return 1; }
    log_ok "Dock d'Ubuntu remplacé par celui du dépôt."
  fi
}
