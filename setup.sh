#!/usr/bin/env bash
# setup.sh — point d'entrée de la configuration du poste (Ubuntu 26.04).
#
#   ./setup.sh                 menu interactif (modules non faits précochés)
#   ./setup.sh <module...>     exécute ces modules et leurs dépendances, sans menu
#   ./setup.sh --all           tous les modules
#   ./setup.sh --list          groupe, nom, description et état de chaque module
#
# Tourne avec le compte utilisateur (jamais root) ; le mot de passe sudo est
# demandé une seule fois. Les modules vivent dans $MODULES_DIR (défaut modules/)
# et suivent le contrat décrit dans lib/module.sh. Journal complet sous
# ~/.local/state/dotfiles/. Voir openspec/changes/setup-socle/design.md.
set -euo pipefail

DOTFILES_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export DOTFILES_DIR
# shellcheck source=lib/core.sh
source "$DOTFILES_DIR/lib/core.sh"
# shellcheck source=lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

usage() {
  cat >&2 <<'USAGE'
Usage : setup.sh [--list | --all | <module...>]

  (sans argument)   menu interactif, modules non faits précochés
  <module...>       exécute ces modules et leurs dépendances, sans menu
  --all             tous les modules
  --list            groupe, nom, description et état de chaque module
USAGE
}

# --- Registre des modules découverts (indexé par nom) --------------------------------
declare -A MOD_FILE MOD_DESC MOD_GROUP MOD_DEPS MOD_GUI MOD_STATE
MOD_NAMES=()          # noms dans l'ordre des fichiers (préfixe NN)
declare -A RESULT     # nom → fait | deja-fait | saute | echoue | indisponible
declare -A RESULT_WHY # nom → précision (ex. dépendance échouée)

# discover_modules : charge les métadonnées de chaque $MODULES_DIR/NN-*.sh
# (module_meta valide le contrat), puis vérifie le graphe des dépendances.
# Tout module invalide, dépendance inconnue ou cycle empêche le démarrage.
discover_modules() {
  local f meta name desc group deps gui
  shopt -s nullglob
  for f in "$MODULES_DIR"/[0-9][0-9]-*.sh; do
    meta=$(module_meta "$f") || die "Module invalide : $f — corriger le module avant de relancer."
    IFS='|' read -r name desc group deps gui <<<"$meta"
    [[ -z ${MOD_FILE[$name]:-} ]] || die "Module « $name » défini deux fois : ${MOD_FILE[$name]} et $f"
    MOD_FILE[$name]=$f MOD_DESC[$name]=$desc MOD_GROUP[$name]=$group
    MOD_DEPS[$name]=${deps//,/ } MOD_GUI[$name]=$gui
    MOD_NAMES+=("$name")
  done
  shopt -u nullglob
  (( ${#MOD_NAMES[@]} > 0 )) || die "Aucun module trouvé dans $MODULES_DIR"
  check_graph
}

# check_graph : dépendances inconnues et cycles (parcours en profondeur avec
# marquage gris/noir), détectés avant toute exécution.
declare -A _COLOR
check_graph() {
  local name dep
  for name in "${MOD_NAMES[@]}"; do
    for dep in ${MOD_DEPS[$name]}; do
      [[ -n ${MOD_FILE[$dep]:-} ]] || die "Le module « $name » dépend de « $dep », qui n'existe pas (fichier ${MOD_FILE[$name]})."
    done
  done
  for name in "${MOD_NAMES[@]}"; do
    _visit "$name" ""
  done
}
_visit() {
  local name=$1 path=$2 dep
  case ${_COLOR[$name]:-} in
    noir) return 0 ;;
    gris) die "Dépendance circulaire : ${path# → } → $name" ;;
  esac
  _COLOR[$name]=gris
  for dep in ${MOD_DEPS[$name]}; do
    _visit "$dep" "$path → $name"
  done
  _COLOR[$name]=noir
}

# compute_states : état de chaque module via module_check (seule source de vérité).
compute_states() {
  local name
  for name in "${MOD_NAMES[@]}"; do
    MOD_STATE[$name]=$(module_state "$name")
  done
}
module_state() {
  local name=$1
  if [[ ${MOD_GUI[$name]} == 1 ]] && ! has_gui; then
    printf 'indisponible'
  elif module_call "${MOD_FILE[$name]}" module_check 2>>"$LOG_FILE"; then
    printf 'fait'
  else
    printf 'a-faire'
  fi
}
state_label() {
  case $1 in
    fait)         printf 'déjà fait' ;;
    a-faire)      printf 'à faire' ;;
    indisponible) printf 'non disponible ici' ;;
  esac
}

# pad <texte> <largeur> : texte complété d'espaces jusqu'à <largeur> caractères
# (printf %-Ns compte des octets et décale les accents).
pad() {
  local text=$1 width=$2
  printf '%s%*s' "$text" $(( width > ${#text} ? width - ${#text} : 0 )) ''
}

# list_modules : `--list`, table alignée groupe / nom / description / état.
list_modules() {
  local name wg=0 wn=0 wd=0
  for name in "${MOD_NAMES[@]}"; do
    (( ${#MOD_GROUP[$name]} + 2 > wg )) && wg=$(( ${#MOD_GROUP[$name]} + 2 ))
    (( ${#name} > wn )) && wn=${#name}
    (( ${#MOD_DESC[$name]} > wd )) && wd=${#MOD_DESC[$name]}
  done
  for name in "${MOD_NAMES[@]}"; do
    printf '%s %s  %s  %s\n' "$(pad "[${MOD_GROUP[$name]}]" "$wg")" "$(pad "$name" "$wn")" \
      "$(pad "${MOD_DESC[$name]}" "$wd")" "$(state_label "${MOD_STATE[$name]}")"
  done
}

# --- Sélection ---------------------------------------------------------------------------
# select_from_menu : `gum choose --no-limit`, libellé « [groupe] nom — description — état »,
# modules à faire précochés. Imprime les noms choisis, un par ligne.
select_from_menu() {
  local name label labels=() preselected="" chosen rc=0
  for name in "${MOD_NAMES[@]}"; do
    label="[${MOD_GROUP[$name]}] $name — ${MOD_DESC[$name]} — $(state_label "${MOD_STATE[$name]}")"
    labels+=("$label")
    [[ ${MOD_STATE[$name]} == a-faire ]] && preselected+="${preselected:+,}$label"
  done
  chosen=$(ui_choose_multi "Modules à exécuter (espace : cocher, entrée : valider) :" "$preselected" "${labels[@]}") || rc=$?
  (( rc == 0 )) || die "Sélection annulée."
  while IFS= read -r label; do
    [[ -n $label ]] || continue
    label=${label#\[*\] }
    printf '%s\n' "${label%% — *}"
  done <<<"$chosen"
}

# resolve_order <nom...> : ordre d'exécution — dépendances d'abord (parcours en
# profondeur, chaque module une fois), puis « 1password » et ses dépendances
# avancés devant tout le reste (D6). Imprime les noms, un par ligne.
# Tableaux de travail globaux : les références de nom (local -n) ne se prêtent
# pas à la récursion en Bash (référence circulaire dès le second niveau).
declare -A _SEEN _CLOSURE
_ORDERED=()
resolve_order() {
  local name op_side=() others=()
  _SEEN=() _ORDERED=()
  for name in "$@"; do
    _topo "$name"
  done
  if [[ -n ${_SEEN[1password]:-} ]]; then
    _CLOSURE=()
    _closure_of 1password
    for name in "${_ORDERED[@]}"; do
      if [[ -n ${_CLOSURE[$name]:-} ]]; then op_side+=("$name"); else others+=("$name"); fi
    done
    _ORDERED=("${op_side[@]}" "${others[@]}")
  fi
  printf '%s\n' "${_ORDERED[@]}"
}
_topo() {
  local name=$1 dep
  [[ -z ${_SEEN[$name]:-} ]] || return 0
  _SEEN[$name]=1
  for dep in ${MOD_DEPS[$name]}; do
    _topo "$dep"
  done
  _ORDERED+=("$name")
}
_closure_of() {
  local name=$1 dep
  _CLOSURE[$name]=1
  for dep in ${MOD_DEPS[$name]}; do
    _closure_of "$dep"
  done
}

# --- Exécution --------------------------------------------------------------------------
# run_modules <nom...> (déjà ordonnés) : check → install → configure, chaque
# fonction dans un sous-shell ; un échec n'arrête pas les autres, mais les modules
# qui en dépendent sont sautés. Les modules graphiques sans GUI sont sautés.
run_modules() {
  local total=$# i=0 name dep blocked
  for name in "$@"; do
    i=$((i + 1))
    log_step "[$i/$total] $name — ${MOD_DESC[$name]}"
    blocked=""
    for dep in ${MOD_DEPS[$name]}; do
      case ${RESULT[$dep]:-} in
        echoue|saute|indisponible) blocked=$dep ;;
      esac
    done
    if [[ -n $blocked ]]; then
      RESULT[$name]=saute RESULT_WHY[$name]="dépend de « $blocked »"
      log_warn "Sauté : dépend de « $blocked » ($(result_label "${RESULT[$blocked]}"))."
      continue
    fi
    if [[ ${MOD_GUI[$name]} == 1 ]] && ! has_gui; then
      RESULT[$name]=indisponible
      log_warn "Non disponible ici : nécessite une session graphique."
      continue
    fi
    if module_call "${MOD_FILE[$name]}" module_check 2>>"$LOG_FILE"; then
      RESULT[$name]=deja-fait
      log_ok "Déjà fait."
      continue
    fi
    if module_call "${MOD_FILE[$name]}" module_install && module_call "${MOD_FILE[$name]}" module_configure; then
      RESULT[$name]=fait
      log_ok "Fait."
    else
      RESULT[$name]=echoue
      log_error "Échec du module « $name » — les modules qui en dépendent seront sautés."
    fi
  done
}

# print_summary <nom...> : table des résultats, étapes manuelles, journal si échec.
# Renvoie 1 si au moins un module a échoué.
print_summary() {
  local name failed=0 symbol color why
  printf '\n' >&2
  ui_header "Résumé"
  for name in "$@"; do
    why=${RESULT_WHY[$name]:+ (${RESULT_WHY[$name]})}
    case ${RESULT[$name]} in
      fait)         symbol='✔' color=$_C_GREEN  ;;
      deja-fait)    symbol='·' color=$_C_DIM    ;;
      saute)        symbol='↷' color=$_C_YELLOW ;;
      indisponible) symbol='–' color=$_C_DIM    ;;
      echoue)       symbol='✖' color=$_C_RED; failed=1 ;;
    esac
    printf '%s%s %s %s%s%s\n' "$color" "$symbol" "$(pad "$name" 14)" "$(result_label "${RESULT[$name]}")" "$why" "$_C_RESET" >&2
    printf '[%s] RESUME %s : %s%s\n' "$(date +%H:%M:%S)" "$name" "${RESULT[$name]}" "$why" >>"$LOG_FILE"
  done
  if [[ -s $MANUAL_STEPS_FILE ]]; then
    printf '\n%sÉtapes manuelles restantes%s\n' "$_C_BOLD" "$_C_RESET" >&2
    while IFS=$'\t' read -r name why; do
      printf '  • [%s] %s\n' "$name" "$why" >&2
    done <"$MANUAL_STEPS_FILE"
  fi
  if (( failed )); then
    printf '\n%sAu moins un module a échoué. Journal complet : %s%s\n' "$_C_RED" "$LOG_FILE" "$_C_RESET" >&2
    return 1
  fi
  printf '\n%sJournal : %s%s\n' "$_C_DIM" "$LOG_FILE" "$_C_RESET" >&2
}
result_label() {
  case $1 in
    fait)         printf 'fait' ;;
    deja-fait)    printf 'déjà fait' ;;
    saute)        printf 'sauté' ;;
    indisponible) printf 'non disponible ici' ;;
    echoue)       printf 'échoué' ;;
  esac
}

# --- Programme principal -----------------------------------------------------------------
main() {
  require_not_root
  local mode=menu selected=() name
  case ${1:-} in
    -h|--help) usage; return 0 ;;
    --list)    mode=list ;;
    --all)     mode=all ;;
    --*)       usage; die "Option inconnue : $1" ;;
    "")        mode=menu ;;
    *)         mode=names ;;
  esac

  discover_modules
  compute_states

  case $mode in
    list)  list_modules; return 0 ;;
    all)   selected=("${MOD_NAMES[@]}") ;;
    names)
      for name in "$@"; do
        [[ -n ${MOD_FILE[$name]:-} ]] || die "Module inconnu : « $name ». Modules valides : ${MOD_NAMES[*]}"
        selected+=("$name")
      done ;;
    menu)
      mapfile -t selected < <(select_from_menu)
      (( ${#selected[@]} > 0 )) || { log_info "Aucun module sélectionné."; return 0; }
      ;;
  esac

  local order
  mapfile -t order < <(resolve_order "${selected[@]}")
  log_info "Ordre d'exécution : ${order[*]}"
  sudo_keepalive
  run_modules "${order[@]}"
  print_summary "${order[@]}"
}

main "$@"
