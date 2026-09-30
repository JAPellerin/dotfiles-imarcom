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
# chaque session (`/etc/xdg/autostart/solaar.desktop`, fenêtre masquée, icône
# dans la barre du haut) et lanceur dans le menu. Les réglages des appareils
# (`~/.config/solaar/config.yaml`) restent à l'utilisateur (D1, D2).
# Voir openspec/changes/solaar/specs/module-solaar/spec.md et openspec/changes/solaar/design.md.
MODULE_NAME="solaar"
MODULE_DESC="Solaar (périphériques Logitech ; dépôts Ubuntu)"
MODULE_GROUP="bureau"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

SOLAAR_PACKAGE="solaar"

# Déjà fait = paquet installé (D2). Lu sans sudo ni réseau : règles udev et
# démarrage automatique viennent du paquet, rien de plus à constater.
module_check() {
  pkg_installed "$SOLAAR_PACKAGE"
}

# apt_install est non interactif : la question debconf reste à sa valeur par
# défaut (pas de groupe plugdev), qui est celle voulue (D1).
module_install() {
  apt_install "$SOLAAR_PACKAGE"
}

module_configure() {
  return 0
}
