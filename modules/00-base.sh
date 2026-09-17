#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/00-base.sh — paquets de base et mise à jour du système.
# Voir openspec/changes/setup-socle/specs/module-base/spec.md.
MODULE_NAME="base"
MODULE_DESC="Mise à jour du système et paquets de base (curl git jq build-essential…)"
MODULE_GROUP="systeme"
MODULE_DEPS=""

BASE_PACKAGES=(
  curl wget git ca-certificates gnupg build-essential make jq unzip
  apt-transport-https software-properties-common
)

module_check() {
  local pkg
  for pkg in "${BASE_PACKAGES[@]}"; do
    pkg_installed "$pkg" || return 1
  done
  return 0
}

module_install() {
  # Question posée avant toute action longue (contrat de module) ; oui par défaut.
  if ui_confirm "Mettre le système à jour d'abord (apt update && apt upgrade) ?" oui; then
    apt_update_once
    ui_spin "Mise à niveau des paquets (apt upgrade)" \
      run_sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q
  else
    log_warn "Mise à niveau du système sautée."
  fi
  apt_install "${BASE_PACKAGES[@]}"
}

module_configure() { :; }
