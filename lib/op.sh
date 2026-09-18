#!/usr/bin/env bash
# lib/op.sh — helpers 1Password CLI (`op`) : état de session, lecture de secret,
# connexion interactive. Les secrets ne passent JAMAIS par le journal : op_read
# renvoie la valeur sur stdout et les modules la reçoivent dans une variable
# (`token=$(op_read op://…)`), sans `echo` ni `run`.
#
# Références : https://developer.1password.com/docs/cli/reference/commands/read
#              https://developer.1password.com/docs/cli/sign-in-manually
# Dépend de lib/core.sh (log_*).

# Les modules tournent en sous-shell (D4) : une session ouverte par `op signin`
# dans un module ne peut pas être exportée vers le runner. Elle est donc écrite
# dans un fichier temporaire (0600, supprimé à la sortie) que op_session_active
# recharge avant chaque vérification. Jamais journalisé.
OP_SESSION_FILE="${OP_SESSION_FILE:-$(mktemp -t dotfiles-op-session.XXXXXX)}"
export OP_SESSION_FILE
add_cleanup "rm -f '$OP_SESSION_FILE'"

# Socket de l'agent SSH de l'application de bureau : créé par l'app dès que
# « Use the SSH agent » est activé et l'app déverrouillée. Sa présence se teste
# sans solliciter l'app (aucune demande d'autorisation), contrairement à `op`.
# Surchargeable pour les tests.
OP_AGENT_SOCK="${OP_AGENT_SOCK:-$HOME/.1password/agent.sock}"

# op_agent_ready : vrai si le socket de l'agent SSH existe.
op_agent_ready() { [[ -S $OP_AGENT_SOCK ]]; }

# Dossier des réglages de l'app : créé à l'instant où l'utilisateur termine sa
# connexion dans l'app (observé en VM le 18 sept 2026 : « Lock state changed:
# Unlocked » puis « Settings file changed », avant tout réglage), donc signal
# « app connectée » qui ne sollicite pas l'app. Surchargeable pour les tests.
OP_APP_SETTINGS_DIR="${OP_APP_SETTINGS_DIR:-$HOME/.config/1Password/settings}"

# op_app_signed_in : vrai si l'app de bureau a déjà été connectée à un compte.
op_app_signed_in() { [[ -d $OP_APP_SETTINGS_DIR ]]; }

# op_session_active : vrai si `op` est installé et qu'une session est ouverte
# (intégration avec l'app de bureau ou session ouverte par op_signin_interactive).
op_session_active() {
  command -v op >/dev/null 2>&1 || return 1
  # shellcheck source=/dev/null
  [[ -s $OP_SESSION_FILE ]] && source "$OP_SESSION_FILE"
  op whoami >/dev/null 2>&1
}

# op_read <op://coffre/item/champ> : renvoie le secret sur stdout.
# Échoue (code non nul, message explicite) si la référence est mal formée ou
# qu'aucune session n'est active. N'écrit rien dans le journal.
op_read() {
  local ref=${1:-}
  if [[ $ref != op://* ]]; then
    log_error "op_read : référence invalide « $ref » (attendu op://<coffre>/<item>/<champ>)"
    return 1
  fi
  if ! op_session_active; then
    log_error "Aucune session 1Password active : lancer « setup.sh 1password » puis relancer ce module."
    return 1
  fi
  op read --no-newline "$ref"
}

# op_signin_interactive : connexion en terminal (sans app de bureau).
# Ajoute le compte s'il n'y en a aucun (`op account add`, questions posées par op :
# adresse, courriel, clé secrète, mot de passe — rien n'est stocké par le script),
# puis exporte la session dans l'environnement du runner (`eval "$(op signin)"`)
# pour que les modules suivants héritent de la variable OP_SESSION_<compte>.
op_signin_interactive() {
  command -v op >/dev/null 2>&1 || { log_error "op (1password-cli) n'est pas installé."; return 1; }
  if [[ $(op account list --format json 2>/dev/null) == "[]" || -z $(op account list 2>/dev/null) ]]; then
    log_info "Aucun compte 1Password configuré : ajout interactif (op account add)."
    # `op account add` demande lui-même adresse, courriel, Secret Key et mot de
    # passe ; il n'offre aucun moyen de masquer la Secret Key (ni flag, ni
    # variable, ni stdin). On prévient, puis on efface écran et historique de
    # défilement (ESC[3J, terminaux compatibles xterm) pour ne pas la laisser visible.
    log_warn "La Secret Key s'affichera en clair pendant la saisie ; le terminal sera effacé ensuite."
    if op account add </dev/tty; then
      printf '\033[2J\033[3J\033[H' >/dev/tty
      log_ok "Compte 1Password ajouté (écran effacé)."
    else
      log_error "Ajout du compte 1Password interrompu."
      return 1
    fi
  fi
  local session
  session=$(op signin </dev/tty) || { log_error "Connexion 1Password interrompue."; return 1; }
  eval "$session"
  printf '%s\n' "$session" >"$OP_SESSION_FILE"
  op_session_active || { log_error "Session 1Password toujours inactive après op signin."; return 1; }
  log_ok "Session 1Password active ($(op whoami --format json 2>/dev/null | sed -n 's/.*"email": *"\([^"]*\)".*/\1/p'))"
}
