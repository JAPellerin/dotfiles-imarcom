#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/53-orca.sh — Orca, l'environnement qui mène plusieurs agents de code en
# parallèle, depuis le `.deb` officiel le plus récent des releases GitHub de
# l'éditeur ; profil AppArmor qui le laisse démarrer ; ajout des dépôts signalé
# au résumé.
#   https://onorca.dev
#   https://github.com/stablyai/orca/releases
#
# Pas de dépôt apt : comme `obsidian`, le helper retient la dernière release qui
# contient le `.deb` ; les mises à jour se font dans l'application (D1). Profil
# AppArmor versionné, comme `rocketchat` : le chrome-sandbox setuid du paquet ne
# suffit pas sous Ubuntu 26.04 (D3). Rien à voir avec le lecteur d'écran `orca`
# de GNOME : paquet `orca-ide`, lanceur `orca-ide.desktop`.
# Voir openspec/specs/module-orca/spec.md et openspec/changes/archive/2026-09-30-orca/design.md.
MODULE_NAME="orca"
MODULE_DESC="Orca (IDE d'agents en parallèle ; .deb officiel des releases GitHub)"
MODULE_GROUP="apps"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

ORCA_REPO="stablyai/orca"
ORCA_ASSET_PATTERN='_amd64\.deb$'
ORCA_PACKAGE="orca-ide"
# Racine surchargeable (tests), comme ROCKETCHAT_ROOT.
ORCA_ROOT="${ORCA_ROOT:-}"
ORCA_APPARMOR_SRC="config/orca/apparmor-profile"
ORCA_APPARMOR="$ORCA_ROOT/etc/apparmor.d/opt.Orca.orca-ide"
# Profil que poserait un paquet bâti par un electron-builder plus récent, attaché
# au même exécutable : deux attachements → exec refusé (D3, « Risks »).
ORCA_APPARMOR_UPSTREAM="$ORCA_ROOT/etc/apparmor.d/orca-ide"
ORCA_REPOS_MANUAL="Ouvrir Orca (menu des applications) et y ajouter ses dépôts de travail (~/projets/…)."

# Déjà fait = paquet installé et profil AppArmor identique au dépôt (D1, D3).
# Lu sans sudo ni réseau ; le chargement du profil n'est pas lisible sans root :
# le fichier en tient lieu, AppArmor charge /etc/apparmor.d/ à chaque démarrage.
module_check() {
  pkg_installed "$ORCA_PACKAGE" || return 1
  cmp -s -- "$DOTFILES_DIR/$ORCA_APPARMOR_SRC" "$ORCA_APPARMOR"
}

# Paquet déjà là : retour sans interroger GitHub (D1). L'étape des dépôts est
# déclarée ici et non dans module_configure : le runner lance chaque fonction
# dans son propre sous-shell (D2).
module_install() {
  if pkg_installed "$ORCA_PACKAGE"; then
    log_ok "Paquet déjà installé : $ORCA_PACKAGE"
    return 0
  fi
  local url
  url=$(github_release_asset_url "$ORCA_REPO" "$ORCA_ASSET_PATTERN") || return 1
  log_info "Orca : $url"
  apt_install_deb_url "$url" "$ORCA_PACKAGE" || return 1
  manual_step "$ORCA_REPOS_MANUAL"
}

# Profil AppArmor (D3) : chargé seulement s'il vient d'être écrit ; retiré si le
# chargement échoue, pour que module_check ne tienne pas pour fait un profil
# jamais chargé. Un profil du paquet au même attachement est signalé, jamais
# retiré (il n'est pas au script).
module_configure() {
  if [[ -e $ORCA_APPARMOR_UPSTREAM ]]; then
    log_warn "Profil AppArmor du paquet présent : $ORCA_APPARMOR_UPSTREAM — deux profils attachés à /opt/Orca/orca-ide empêchent Orca de démarrer ; en retirer un (sudo apparmor_parser -R <fichier>, puis supprimer le fichier)."
  fi
  if cmp -s -- "$DOTFILES_DIR/$ORCA_APPARMOR_SRC" "$ORCA_APPARMOR"; then
    log_ok "Profil AppArmor déjà à jour : $ORCA_APPARMOR"
    return 0
  fi
  install_system_file "$ORCA_APPARMOR_SRC" "$ORCA_APPARMOR" || return 1
  if ! run_sudo apparmor_parser -r "$ORCA_APPARMOR"; then
    log_error "Chargement du profil AppArmor impossible : $ORCA_APPARMOR (retiré)"
    run_sudo rm -f -- "$ORCA_APPARMOR"
    return 1
  fi
  log_ok "Profil AppArmor chargé : $ORCA_APPARMOR"
}
