#!/usr/bin/env bash
# lib/op.sh — helpers 1Password CLI (`op`) : état de session, lecture de secret,
# connexion interactive. Les secrets ne passent JAMAIS par le journal : op_read
# renvoie la valeur sur stdout et les modules la reçoivent dans une variable
# (`token=$(op_read op://…)`), sans `echo` ni `run`.
#
# Références : https://developer.1password.com/docs/cli/reference/commands/read
#              https://developer.1password.com/docs/cli/sign-in-manually
# Dépend de lib/core.sh (log_*).

# op_session_active : vrai si `op` est installé et qu'une session est ouverte
# (intégration avec l'app de bureau ou session exportée par op_signin_interactive).
op_session_active() {
  command -v op >/dev/null 2>&1 || return 1
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
    op account add </dev/tty || { log_error "Ajout du compte 1Password interrompu."; return 1; }
  fi
  local session
  session=$(op signin </dev/tty) || { log_error "Connexion 1Password interrompue."; return 1; }
  eval "$session"
  op_session_active || { log_error "Session 1Password toujours inactive après op signin."; return 1; }
  log_ok "Session 1Password active ($(op whoami --format json 2>/dev/null | sed -n 's/.*"email": *"\([^"]*\)".*/\1/p'))"
}
