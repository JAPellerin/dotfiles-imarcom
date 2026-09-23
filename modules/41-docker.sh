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

# Déjà fait = les cinq paquets installés, l'utilisateur membre du groupe `docker`
# dans la base des groupes, le service activé et en marche (D6). Tout se lit
# localement, sans réseau ni sudo. La session à rouvrir n'y entre pas (D5).
# Groupe : helpers de lib/groups.sh (base des groupes, pas la session).
module_check() {
  local pkg
  for pkg in "${DOCKER_PACKAGES[@]}"; do
    pkg_installed "$pkg" || return 1
  done
  user_in_group "$DOCKER_GROUP" || return 1
  _docker_service_ok
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

# Groupe créé s'il manque (le paquet le crée normalement, la doc
# post-installation le fait créer quand même), utilisateur inscrit s'il n'est
# pas déjà membre (D3) ; puis le service ; puis, tant que la session ne porte
# pas le groupe, l'étape « rouvrir la session » au résumé final (D5).
module_configure() {
  ensure_user_in_group "$DOCKER_GROUP" || return 1
  _docker_ensure_service || return 1
  group_relogin_step "$DOCKER_GROUP"
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
