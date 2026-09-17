#!/usr/bin/env bash
# lib/module.sh — contrat de module (D4) : chargement d'un module en sous-shell,
# validation de ses métadonnées, appel de ses fonctions, étapes manuelles.
#
# Un module est un fichier $MODULES_DIR/NN-<nom>.sh qui déclare :
#   MODULE_NAME="<nom>"            identique au <nom> du fichier
#   MODULE_DESC="…"                une ligne, en français
#   MODULE_GROUP="systeme"         parmi $MODULE_GROUPS
#   MODULE_DEPS="base 1password"   noms de modules séparés par des espaces ("" si aucun)
#   MODULE_NEEDS_GUI=1             facultatif : nécessite une session graphique
# et trois fonctions : module_check (0 = déjà fait, 1 = à faire, sans effet de
# bord), module_install, module_configure.
# Comme le fichier est sourcé par le runner, shellcheck voit ces métadonnées
# comme inutilisées : chaque module commence par la directive
#   # shellcheck disable=SC2034  # métadonnées lues par le runner
# Voir openspec/changes/setup-socle/specs/module-contract/spec.md.
# Dépend de lib/core.sh (log_*, add_cleanup).

MODULES_DIR="${MODULES_DIR:-$DOTFILES_DIR/modules}"
MODULE_GROUPS="systeme shell dev apps bureau projets"

# Fichier des étapes manuelles déclarées par les modules ; le runner le lit pour
# le résumé final. Hérité par les sous-shells des modules.
MANUAL_STEPS_FILE="${MANUAL_STEPS_FILE:-$(mktemp -t dotfiles-manual.XXXXXX)}"
export MODULES_DIR MANUAL_STEPS_FILE
add_cleanup "rm -f '$MANUAL_STEPS_FILE'"

# manual_step <texte> : déclare une étape que le script ne peut pas automatiser.
# Appelée depuis un module ; consignée sous la forme « <module><TAB><texte> ».
manual_step() {
  printf '%s\t%s\n' "${MODULE_NAME:-?}" "$*" >>"$MANUAL_STEPS_FILE"
  log_info "Étape manuelle à faire ensuite : $*"
}

# module_name_from_file <fichier> : « 10-1password.sh » → « 1password ».
module_name_from_file() {
  local base
  base=$(basename -- "$1" .sh)
  printf '%s\n' "${base#[0-9][0-9]-}"
}

# module_meta <fichier> : charge le module dans un sous-shell propre, valide ses
# métadonnées et ses fonctions, puis imprime une ligne sur stdout :
#   nom<TAB>description<TAB>groupe<TAB>dépendances<TAB>needs_gui(0|1)
# Code non nul et message nommant le fichier et le champ fautif sinon.
module_meta() {
  local file=$1
  [[ -f $file ]] || { log_error "Module introuvable : $file"; return 1; }
  (
    unset MODULE_NAME MODULE_DESC MODULE_GROUP MODULE_DEPS MODULE_NEEDS_GUI
    unset -f module_check module_install module_configure
    # shellcheck source=/dev/null
    source "$file" || { log_error "$file : échec au chargement du module"; exit 1; }
    expected=$(module_name_from_file "$file")
    err=0
    for var in MODULE_NAME MODULE_DESC MODULE_GROUP; do
      [[ -n ${!var:-} ]] || { log_error "$file : $var manquant ou vide"; err=1; }
    done
    [[ -v MODULE_DEPS ]] || { log_error "$file : MODULE_DEPS manquant (mettre MODULE_DEPS=\"\" si aucune dépendance)"; err=1; }
    if [[ -n ${MODULE_NAME:-} && $MODULE_NAME != "$expected" ]]; then
      log_error "$file : MODULE_NAME « $MODULE_NAME » ne correspond pas au nom de fichier (attendu « $expected »)"; err=1
    fi
    if [[ -n ${MODULE_GROUP:-} ]] && ! [[ " $MODULE_GROUPS " == *" $MODULE_GROUP "* ]]; then
      log_error "$file : MODULE_GROUP « $MODULE_GROUP » inconnu (valeurs : $MODULE_GROUPS)"; err=1
    fi
    for fn in module_check module_install module_configure; do
      declare -F "$fn" >/dev/null || { log_error "$file : fonction $fn manquante"; err=1; }
    done
    (( err == 0 )) || exit 1
    # shellcheck disable=SC2153  # MODULE_DESC est défini par le module sourcé
    printf '%s\t%s\t%s\t%s\t%s\n' "$MODULE_NAME" "$MODULE_DESC" "$MODULE_GROUP" "${MODULE_DEPS// /,}" "${MODULE_NEEDS_GUI:-0}"
  )
}

# module_call <fichier> <fonction> : exécute module_<fonction> dans un sous-shell
# (isolation : les variables et fonctions du module ne fuient pas, un échec ne tue
# pas le runner). Renvoie le code de la fonction.
module_call() {
  local file=$1 fn=$2
  (
    # shellcheck source=/dev/null
    source "$file" || exit 1
    "$fn"
  )
}
