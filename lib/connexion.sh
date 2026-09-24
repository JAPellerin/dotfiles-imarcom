#!/usr/bin/env bash
# lib/connexion.sh — connexion guidée par 1Password et ouverture détachée d'une
# application, pour les applications qui n'acceptent aucune connexion scriptée
# (ni jeton, ni API) : le script prépare le secret dans le presse-papiers, ouvre
# l'application, donne la consigne et attend un signe sur disque de la connexion.
#
# Garde-fous du secret : lu dans une variable (jamais passé à run ni à log_*),
# copié par wl-copy puis oublié ; presse-papiers vidé à la fin du parcours dans
# tous les cas — connexion constatée, « Passer », Ctrl-C (nettoyage enregistré par
# add_cleanup avant la copie, exécuté à la sortie du sous-shell de module_call).
# Jamais bloquant : tout empêchement devient une étape manuelle.
# Voir openspec/changes/socle-connexion/design.md (D2 à D4).
# Dépend de lib/core.sh (log_*, add_cleanup, has_gui), lib/ui.sh (ui_wait,
# ui_choose), lib/apt.sh (apt_install), lib/op.sh (op_session_active, op_read)
# et lib/module.sh (manual_step).

# Délais de l'attente, surchargeables (tests).
CONNEXION_WAIT_SECONDS="${CONNEXION_WAIT_SECONDS:-300}"
CONNEXION_WAIT_INTERVAL="${CONNEXION_WAIT_INTERVAL:-2}"

# open_detached <commande…> : lance une application détachée du script (setsid),
# sorties vers /dev/null — elle hériterait sinon du terminal et du journal, et y
# écrirait ses propres traces tant qu'elle tourne (vu en VM avec 1Password). La
# commande est tracée au journal. Jamais d'échec : avertissement si elle manque
# ou ne démarre pas.
open_detached() {
  local cmd=${1:-}
  [[ -n $cmd ]] || { log_error "open_detached : commande manquante"; return 1; }
  if ! command -v -- "$cmd" >/dev/null 2>&1; then
    log_warn "Impossible de lancer $cmd : l'ouvrir à la main."
    return 0
  fi
  printf '[%s] $ %s (détaché)\n' "$(date +%H:%M:%S)" "$*" >>"$LOG_FILE"
  setsid -f "$@" >/dev/null 2>&1 </dev/null \
    || log_warn "Impossible de lancer $cmd : l'ouvrir à la main."
  return 0
}

# _connexion_clear : vide le presse-papiers (sans erreur s'il est indisponible).
_connexion_clear() { wl-copy --clear >/dev/null 2>&1 || true; }

# guided_login <libellé> <sonde> <étape manuelle> [options] [-- <consigne>…]
#   --secret <op://…>     secret lu par op_read, copié dans le presse-papiers
#   --secret-fn <fonct.>  la fonction imprime le secret sur stdout (secret calculé) ;
#                         elle avertit elle-même et échoue si elle ne peut pas
#   --user <op://…>       identifiant lu par op_read et affiché (pas un secret)
#   --open <commande…> ;  ouvre l'application (le « ; » isolé termine la commande)
#   -- <consigne>…        une ligne par étape, numérotées ici
# La sonde réussit quand la connexion est faite, sans sudo ni réseau : c'est celle
# que le module emploie aussi dans module_check (D5). Rend toujours 0, sauf
# arguments invalides : le module lit son état par la sonde.
guided_login() {
  (( $# >= 3 )) || { log_error "guided_login : arguments manquants (libellé, sonde, étape manuelle)"; return 1; }
  local label=$1 probe=$2 manual=$3
  shift 3
  local secret_ref='' secret_fn='' user_ref='' open_cmd=() steps=()
  while (( $# )); do
    case $1 in
      --secret|--secret-fn|--user)
        (( $# >= 2 )) || { log_error "guided_login : valeur manquante pour $1"; return 1; }
        case $1 in
          --secret)    secret_ref=$2 ;;
          --secret-fn) secret_fn=$2 ;;
          --user)      user_ref=$2 ;;
        esac
        shift 2 ;;
      --open)
        shift
        while (( $# )) && [[ $1 != ';' ]]; do open_cmd+=("$1"); shift; done
        (( $# )) || { log_error "guided_login : « ; » manquant après --open"; return 1; }
        shift ;;
      --) shift; steps=("$@"); break ;;
      *) log_error "guided_login : option inconnue « $1 »"; return 1 ;;
    esac
  done
  [[ -n $secret_ref && -n $secret_fn ]] \
    && { log_error "guided_login : --secret et --secret-fn s'excluent"; return 1; }

  # 1. Déjà connecté : ni 1Password, ni fenêtre, ni sudo.
  if "$probe" >/dev/null 2>&1; then
    log_ok "$label : déjà fait."
    return 0
  fi
  # 2. Sans session graphique, ni presse-papiers ni fenêtre.
  if ! has_gui; then
    log_warn "$label : pas de session graphique, étape à faire depuis le bureau."
    manual_step "$manual"
    return 0
  fi
  # 3. Lecture dans 1Password demandée sans session.
  if [[ -n $secret_ref || -n $user_ref ]] && ! op_session_active; then
    log_warn "$label : aucune session 1Password, les identifiants ne peuvent pas être lus."
    manual_step "$manual"
    return 0
  fi

  # 4. Secret : dans une variable, copié puis oublié ; vidage prévu avant la copie.
  local secret user='' copied=0 i choice
  if [[ -n $secret_ref || -n $secret_fn ]]; then
    if [[ -n $secret_ref ]]; then
      if ! secret=$(op_read "$secret_ref" 2>>"$LOG_FILE"); then
        log_warn "$label : lecture de « $secret_ref » impossible (voir le journal)."
        manual_step "$manual"
        return 0
      fi
    elif ! secret=$("$secret_fn"); then
      unset secret
      manual_step "$manual"
      return 0
    fi
    if ! command -v wl-copy >/dev/null 2>&1 && ! apt_install wl-clipboard; then
      unset secret
      log_warn "$label : installation de wl-clipboard impossible, presse-papiers indisponible."
      manual_step "$manual"
      return 0
    fi
    add_cleanup _connexion_clear
    if ! printf '%s' "$secret" | wl-copy >/dev/null 2>&1; then
      unset secret
      _connexion_clear
      log_warn "$label : presse-papiers indisponible (wl-copy)."
      manual_step "$manual"
      return 0
    fi
    unset secret
    copied=1
  fi
  if [[ -n $user_ref ]]; then
    user=$(op_read "$user_ref" 2>>"$LOG_FILE") \
      || { user=''; log_warn "$label : identifiant « $user_ref » illisible (voir le journal)."; }
  fi

  # 5. Application, identifiant, consigne.
  if (( ${#open_cmd[@]} )); then
    "${open_cmd[@]}" || true
  fi
  log_info "$label :"
  [[ -n $user ]] && log_info "  Identifiant : $user"
  (( copied )) && log_info "  Presse-papiers prêt à coller (Ctrl-V) ; il sera vidé à la fin de l'étape."
  for i in "${!steps[@]}"; do
    log_info "  $(( i + 1 )). ${steps[i]}"
  done
  log_info "Le script reprend dès que c'est constaté ; Ctrl-C pour abandonner."

  # 6. Attente de la sonde ; au délai écoulé, continuer ou passer.
  while true; do
    if ui_wait "$label : en attente" "$CONNEXION_WAIT_SECONDS" "$CONNEXION_WAIT_INTERVAL" "$probe"; then
      (( copied )) && _connexion_clear
      log_ok "$label : fait$( (( copied )) && printf ' (presse-papiers vidé)')."
      return 0
    fi
    choice=$(ui_choose "$label : pas encore constaté. Que faire ?" \
      "Continuer d'attendre" "Passer (étape manuelle)") || choice="Passer"
    case $choice in
      Continuer*) ;;
      *)
        (( copied )) && _connexion_clear
        manual_step "$manual"
        return 0 ;;
    esac
  done
}
