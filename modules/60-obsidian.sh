#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/60-obsidian.sh — Obsidian depuis le `.deb` officiel le plus récent des
# releases GitHub de l'éditeur ; ouverture du coffre signalée au résumé.
#   https://obsidian.md/download
#   https://github.com/obsidianmd/obsidian-releases/releases
#
# Obsidian ne publie aucun dépôt apt. La release « latest » peut ne contenir
# qu'un `.apk` Android (v1.13.8, relevé du 23 sept 2026) : le helper remonte à la
# dernière release qui contient le `.deb` (design D1). Les mises à jour se font
# dans l'application, le `.deb` n'a pas à suivre (D4).
# Voir openspec/changes/obsidian/specs/module-obsidian/spec.md et openspec/changes/obsidian/design.md
# (à l'archivage : spec principale et design archivé).
MODULE_NAME="obsidian"
MODULE_DESC="Obsidian (.deb officiel des releases GitHub)"
MODULE_GROUP="apps"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

OBSIDIAN_REPO="obsidianmd/obsidian-releases"
OBSIDIAN_ASSET_PATTERN='_amd64\.deb$'
OBSIDIAN_PACKAGE="obsidian"
OBSIDIAN_VAULT_MANUAL="Ouvrir Obsidian (menu des applications) et ouvrir ou synchroniser son coffre de notes."

# Déjà fait = paquet installé (D2). Lu sans sudo ni réseau.
module_check() {
  pkg_installed "$OBSIDIAN_PACKAGE"
}

# Paquet déjà là : retour sans interroger GitHub (D2). L'étape du coffre est
# déclarée ici et non dans module_configure : le runner lance chaque fonction
# dans son propre sous-shell, une variable « paquet absent avant » serait perdue
# en chemin (D3).
module_install() {
  if pkg_installed "$OBSIDIAN_PACKAGE"; then
    log_ok "Paquet déjà installé : $OBSIDIAN_PACKAGE"
    return 0
  fi
  local url
  url=$(github_release_asset_url "$OBSIDIAN_REPO" "$OBSIDIAN_ASSET_PATTERN") || return 1
  log_info "Obsidian : $url"
  apt_install_deb_url "$url" "$OBSIDIAN_PACKAGE" || return 1
  manual_step "$OBSIDIAN_VAULT_MANUAL"
}

module_configure() {
  return 0
}
