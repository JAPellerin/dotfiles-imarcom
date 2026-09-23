#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/41-docker.sh — Docker Engine depuis le dépôt apt officiel de Docker
# (pas Docker Desktop, refusé), utilisable sans sudo par le groupe `docker`.
#
# Suit la doc officielle :
#   https://docs.docker.com/engine/install/ubuntu/            (conflits, dépôt, paquets)
#   https://docs.docker.com/engine/install/linux-postinstall/ (groupe, service)
# Le paquet docker-ce crée déjà le groupe et active le service (postinst relevé
# le 23 sept 2026) : le module les constate et ne les rétablit que s'il le faut.
# Aucun /etc/docker/daemon.json : réglages par défaut de Docker, par décision de
# l'utilisateur, jusqu'à ce qu'un besoin réel se présente.
# Voir openspec/changes/docker/specs/module-docker/spec.md et design.md.
MODULE_NAME="docker"
MODULE_DESC="Docker Engine (dépôt apt officiel) ; compose et buildx ; groupe docker ; service actif"
MODULE_GROUP="dev"
MODULE_DEPS="base"

DOCKER_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
# Paquets non officiels à retirer avant l'installation, tels que la doc les
# nomme (section « Uninstall old versions », 23 sept 2026) — design D2.
DOCKER_CONFLICTS=(docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc)
DOCKER_GROUP="docker"
DOCKER_USER="${USER:-$(id -un)}"
DOCKER_RELOGIN_MANUAL="Fermer puis rouvrir la session : l'appartenance au groupe docker n'est prise en compte qu'à l'ouverture d'une session (docker sans sudo d'ici là)."

# Déjà fait = les cinq paquets installés, l'utilisateur membre du groupe `docker`
# dans la base des groupes, le service activé et en marche (D6). Tout se lit
# localement, sans réseau ni sudo. La session à rouvrir n'y entre pas (D5).
module_check() {
  local pkg
  for pkg in "${DOCKER_PACKAGES[@]}"; do
    pkg_installed "$pkg" || return 1
  done
  _docker_user_in_group || return 1
  _docker_service_ok
}

# _docker_user_in_group : vrai si la base des groupes liste l'utilisateur parmi
# les membres de `docker`. Pas `id -nG`, qui donne les groupes de la session et
# resterait faux jusqu'à la reconnexion (D3). `grep … >/dev/null` et non `-q` :
# sous pipefail, -q peut tuer l'amont par SIGPIPE et renvoyer 141.
_docker_user_in_group() {
  getent group "$DOCKER_GROUP" 2>/dev/null | cut -d: -f4 | tr ',' '\n' \
    | grep -xF -- "$DOCKER_USER" >/dev/null
}

# _docker_session_has_group : vrai si la session courante porte déjà le groupe.
_docker_session_has_group() {
  id -nG 2>/dev/null | tr ' ' '\n' | grep -xF -- "$DOCKER_GROUP" >/dev/null
}

# _docker_service_ok : service activé au démarrage et en marche (D4). Lu sans sudo.
_docker_service_ok() {
  systemctl is-enabled --quiet docker.service 2>/dev/null \
    && systemctl is-active --quiet docker.service 2>/dev/null
}

module_install() {
  apt_remove "${DOCKER_CONFLICTS[@]}" || return 1
  apt_add_repo docker "$DOCKER_KEY_URL" "$DOCKER_REPO_URL" auto stable || return 1
  apt_install "${DOCKER_PACKAGES[@]}"
}

module_configure() {
  _docker_ensure_group || return 1
  _docker_ensure_service || return 1
  _docker_check_session
}

# _docker_ensure_group : groupe créé s'il manque (le paquet le crée normalement,
# la doc post-installation le fait créer quand même), utilisateur ajouté s'il
# n'est pas déjà membre (D3).
_docker_ensure_group() {
  if ! getent group "$DOCKER_GROUP" >/dev/null 2>&1; then
    run_sudo groupadd --system "$DOCKER_GROUP" || return 1
  fi
  if _docker_user_in_group; then
    log_ok "$DOCKER_USER est déjà membre du groupe $DOCKER_GROUP."
    return 0
  fi
  run_sudo usermod -aG "$DOCKER_GROUP" "$DOCKER_USER" || return 1
  if ! _docker_user_in_group; then
    log_error "$DOCKER_USER n'apparaît pas dans le groupe $DOCKER_GROUP après usermod."
    return 1
  fi
  log_ok "$DOCKER_USER ajouté au groupe $DOCKER_GROUP."
}

# _docker_ensure_service : rien si le service est déjà activé et en marche ;
# sinon activation et démarrage des deux unités que nomme la doc, puis nouvelle
# constatation — échec nommé s'il ne tourne toujours pas (D4).
_docker_ensure_service() {
  if _docker_service_ok; then
    log_ok "Service docker activé et en marche."
    return 0
  fi
  run_sudo systemctl enable --now docker.service containerd.service || return 1
  if ! _docker_service_ok; then
    log_error "Le service docker.service ne se constate pas activé et en marche (systemctl status docker.service)."
    return 1
  fi
  log_ok "Service docker activé et démarré."
}

# _docker_check_session : l'appartenance au groupe n'est prise en compte qu'à
# l'ouverture d'une session. Transitoire : ni échec ni critère « déjà fait »,
# mais une ligne dans le résumé final plutôt que dans un journal qui a défilé (D5).
_docker_check_session() {
  _docker_user_in_group || return 0
  _docker_session_has_group && return 0
  log_warn "La session courante ne porte pas encore le groupe $DOCKER_GROUP : docker demande sudo jusqu'à sa réouverture."
  manual_step "$DOCKER_RELOGIN_MANUAL"
}
