#!/usr/bin/env bash
# lib/ui.sh — wrappers d'interface autour de gum (menus, confirmations, saisies,
# spinner). Les modules passent par ces fonctions, jamais par gum en direct.
#
# Référence : https://github.com/charmbracelet/gum (gum 0.17, dépôts Ubuntu 26.04).
# gum dessine son interface sur stderr et lit le clavier sur le terminal ; il n'y a
# aucune redirection globale dans le socle (D7), donc il garde toujours le TTY.
# Les résultats (choix, saisie) sortent sur stdout : `choix=$(ui_choose …)`.
# Dépend de lib/core.sh (log_*, run, couleurs).

# ui_header <titre> : encadré de section, affiché sur stderr.
ui_header() {
  gum style --border rounded --border-foreground 212 --padding "0 1" --bold "$*" >&2
}

# ui_choose <en-tête> <option...> : choix unique, l'option choisie sur stdout.
ui_choose() {
  local header=$1
  shift
  gum choose --header "$header" "$@"
}

# ui_choose_multi <en-tête> <présélection> <option...> : sélection multiple.
# <présélection> = options cochées au départ, séparées par des virgules ("" pour
# aucune). Une option par ligne sur stdout.
ui_choose_multi() {
  local header=$1 selected=$2
  shift 2
  gum choose --no-limit --header "$header" --selected="$selected" "$@"
}

# ui_confirm <question> [oui|non] : renvoie 0 si l'utilisateur confirme.
# Le second argument fixe la réponse proposée par défaut (oui si omis).
# Un Ctrl-C (code 130 de gum) vaut « non ».
ui_confirm() {
  local question=$1 default=${2:-oui} flag=--default=true
  [[ $default == non ]] && flag=--default=false
  gum confirm "$flag" --affirmative "Oui" --negative "Non" "$question"
}

# ui_input <en-tête> [texte indicatif] [valeur initiale] : saisie libre sur stdout.
ui_input() {
  local header=$1 placeholder=${2:-} value=${3:-}
  gum input --header "$header" --placeholder "$placeholder" --value "$value"
}

# ui_password <en-tête> : saisie masquée sur stdout (jamais journalisée).
ui_password() {
  gum input --password --header "$1" --placeholder ""
}

# ui_spin <titre> <commande...> : affiche un spinner pendant la commande, puis
# « ✔ titre » ou l'échec avec l'extrait du journal. À utiliser avec `run` /
# `run_sudo` (la sortie de la commande doit aller au journal, pas à l'écran) :
#   ui_spin "Installation de jq" run_sudo apt-get install -y jq
# Le spinner est une boucle Bash plutôt que `gum spin` afin de pouvoir envelopper
# des fonctions du socle (run, run_sudo, apt_*) et pas seulement des exécutables.
# Sans terminal (journal, tests), pas d'animation : une ligne d'info suffit.
ui_spin() {
  local title=$1 rc=0
  shift
  if [[ ! -t 2 ]]; then
    log_info "$title"
    _UI_SPINNING=1 "$@" || rc=$?
  else
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏') i=0
    printf '\033[?25l' >&2
    (
      while true; do
        printf '\r%s%s%s %s' "$_C_MAGENTA" "${frames[i]}" "$_C_RESET" "$title" >&2
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
      done
    ) &
    local spinner_pid=$!
    _UI_SPINNING=1 "$@" || rc=$?
    kill "$spinner_pid" 2>/dev/null
    wait "$spinner_pid" 2>/dev/null || true
    printf '\r\033[K\033[?25h' >&2
  fi
  if (( rc == 0 )); then
    log_ok "$title"
  else
    _run_report_failure "$rc" "$title"
  fi
  return "$rc"
}
