#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/71-solaar.sh — Solaar, gestionnaire des périphériques Logitech (souris,
# claviers, récepteurs Unifying et Bolt), depuis les dépôts d'Ubuntu : l'équivalent
# de Logi Options+, qui n'existe pas sous Linux.
#   https://pwr-solaar.github.io/Solaar/
#   https://pwr-solaar.github.io/Solaar/installation
#
# Le paquet apporte tout le reste (relevé du 30 sept 2026, solaar 1.1.19-1) : règles
# udev `60-solaar.rules` avec `TAG+="uaccess"` (accès au récepteur donné par les
# ACL de la session locale, sans groupe ni réouverture de session — la question
# debconf `solaar/use_plugdev_group` garde son défaut `false`), démarrage avec
# chaque session (`/etc/xdg/autostart/solaar.desktop`, fenêtre masquée ; l'icône
# apparaît dans la barre du haut dès qu'un récepteur ou un appareil Logitech est
# détecté) et lanceur dans le menu. Les réglages des appareils
# (`~/.config/solaar/config.yaml`) restent à l'utilisateur (D1, D2).
# Ces règles ne valent que pour les événements udev à venir : un récepteur déjà
# branché et /dev/uinput, créé au démarrage, n'ont ni tag ni ACL tant qu'aucun
# événement ne les concerne (relevé en VM). À l'installation, le module recharge
# donc les règles et rejoue un événement « change » sur ces périphériques (D5).
# Voir openspec/changes/solaar/specs/module-solaar/spec.md et openspec/changes/solaar/design.md.
MODULE_NAME="solaar"
MODULE_DESC="Solaar (périphériques Logitech ; dépôts Ubuntu)"
MODULE_GROUP="bureau"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

SOLAAR_PACKAGE="solaar"
# Sous-systèmes des périphériques que les règles du paquet visent : hidraw
# (récepteurs et appareils) et misc (/dev/uinput).
SOLAAR_UDEV_SUBSYSTEMS=(hidraw misc)

# Déjà fait = paquet installé (D2). Lu sans sudo ni réseau : règles udev et
# démarrage automatique viennent du paquet, rien de plus à constater.
module_check() {
  pkg_installed "$SOLAAR_PACKAGE"
}

# apt_install est non interactif : la question debconf reste à sa valeur par
# défaut (pas de groupe plugdev), qui est celle voulue (D1). Quand le paquet
# vient d'être installé, ses règles udev sont rechargées et rejouées sur les
# périphériques déjà présents (D5) ; rien de tout cela sur une relance.
module_install() {
  if pkg_installed "$SOLAAR_PACKAGE"; then
    log_ok "Paquet déjà installé : $SOLAAR_PACKAGE"
    return 0
  fi
  apt_install "$SOLAAR_PACKAGE" || return 1
  _solaar_udev_apply
}

# _solaar_udev_apply : règles udev relues, puis événement « change » rejoué sur
# les périphériques hidraw et misc déjà présents, pour que le tag uaccess et
# les ACL de la session s'appliquent sans redémarrage ni rebranchement
# (https://pwr-solaar.github.io/Solaar/installation : recharger les règles udev).
_solaar_udev_apply() {
  local args=() sub
  for sub in "${SOLAAR_UDEV_SUBSYSTEMS[@]}"; do args+=(--subsystem-match="$sub"); done
  run_sudo udevadm control --reload-rules || { log_error "Rechargement des règles udev impossible : voir le journal."; return 1; }
  run_sudo udevadm trigger --action=change "${args[@]}" || { log_error "Rejeu des événements udev impossible : voir le journal."; return 1; }
  log_ok "Règles udev de Solaar appliquées aux périphériques déjà présents."
}

module_configure() {
  return 0
}
