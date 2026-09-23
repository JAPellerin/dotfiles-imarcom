#!/usr/bin/env bash
# lib/groups.sh — appartenance de l'utilisateur courant à un groupe système :
# constat, inscription, et étape « rouvrir la session » tant que la session en
# cours ne porte pas encore le groupe.
#
# L'appartenance se constate dans la base des groupes (`getent group`), jamais
# par `id -nG` : ce dernier donne les groupes de la session, qui ne changent
# qu'à la reconnexion — un module_check fondé dessus ne serait jamais vrai dans
# la session de l'installation. Repris du module docker, validé en VM le 23 sept
# 2026. Voir openspec/changes/socle-groupes/design.md.
# Dépend de lib/core.sh (run_sudo, log_*) et lib/module.sh (manual_step).

# _group_user : l'utilisateur courant.
_group_user() { printf '%s' "${USER:-$(id -un)}"; }

# user_in_group <groupe> : vrai si la base des groupes liste l'utilisateur parmi
# les membres de <groupe> (comparaison exacte : « uu » n'est pas « u »). Sans
# effet de bord : utilisable comme critère par module_check.
# `grep … >/dev/null` et surtout pas `grep -q` en fin de tube : sous pipefail,
# -q peut tuer l'amont par SIGPIPE et renvoyer 141 (vu sur font_installed).
user_in_group() {
  getent group "$1" 2>/dev/null | cut -d: -f4 | tr ',' '\n' \
    | grep -xF -- "$(_group_user)" >/dev/null
}

# _group_in_session <groupe> : vrai si la session courante porte le groupe.
_group_in_session() {
  id -nG 2>/dev/null | tr ' ' '\n' | grep -xF -- "$1" >/dev/null
}

# ensure_user_in_group <groupe> : crée le groupe s'il n'existe pas (groupe
# système), inscrit l'utilisateur s'il n'est pas déjà membre, puis constate
# l'inscription — échec nommé si elle ne se voit pas dans la base des groupes.
ensure_user_in_group() {
  local group=${1:-} user
  [[ -n $group ]] || { log_error "ensure_user_in_group : groupe manquant"; return 1; }
  user=$(_group_user)
  if ! getent group "$group" >/dev/null 2>&1; then
    run_sudo groupadd --system "$group" || return 1
  fi
  if user_in_group "$group"; then
    log_ok "$user est déjà membre du groupe $group."
    return 0
  fi
  run_sudo usermod -aG "$group" "$user" || return 1
  if ! user_in_group "$group"; then
    log_error "$user n'apparaît pas dans le groupe $group après usermod."
    return 1
  fi
  log_ok "$user ajouté au groupe $group."
}

# group_relogin_step <groupe> : l'appartenance à un groupe n'est prise en compte
# qu'à l'ouverture d'une session. Membre dans la base mais pas dans la session →
# avertissement et étape manuelle nommant le groupe, pour qu'elle figure au
# résumé final. Transitoire : jamais d'échec. Rien si l'utilisateur n'est pas
# membre, ou si la session porte déjà le groupe.
group_relogin_step() {
  local group=$1
  user_in_group "$group" || return 0
  _group_in_session "$group" && return 0
  log_warn "La session courante ne porte pas encore le groupe $group : il faut la rouvrir."
  manual_step "Fermer puis rouvrir la session : l'appartenance au groupe $group n'est prise en compte qu'à l'ouverture d'une session."
}
