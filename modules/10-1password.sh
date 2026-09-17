#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/10-1password.sh — 1Password : app de bureau (si session graphique) et
# CLI `op` depuis le dépôt apt officiel, connexion, agent SSH.
#
# Procédure officielle suivie :
#   app : https://support.1password.com/install-linux/#debian-or-ubuntu
#   CLI : https://www.1password.dev/cli/get-started/
#   SSH : https://developer.1password.com/docs/ssh/get-started
# Même dépôt et même clé que la doc ; seul le format change (deb822 + clé dans
# /etc/apt/keyrings/, voir design D8/D10). La politique debsig demandée par la doc
# est installée telle quelle.
# Voir openspec/changes/setup-socle/specs/module-1password/spec.md.
MODULE_NAME="1password"
MODULE_DESC="1Password : application de bureau (si GUI) et CLI op ; connexion et agent SSH"
MODULE_GROUP="systeme"
MODULE_DEPS="base"

OP_KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
OP_REPO_URL="https://downloads.1password.com/linux/debian/$(dpkg --print-architecture)"
OP_DEBSIG_ID="AC2D62742012EA22"
OP_DEBSIG_POLICY_URL="https://downloads.1password.com/linux/debian/debsig/1password.pol"
OP_DEBSIG_POLICY="/etc/debsig/policies/$OP_DEBSIG_ID/1password.pol"
OP_DEBSIG_KEYRING="/usr/share/debsig/keyrings/$OP_DEBSIG_ID/debsig.gpg"
# shellcheck disable=SC2016  # ligne littérale : $HOME est évalué par le shell qui la charge
OP_AGENT_SOCK_LINE='export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"'

# Déjà fait = CLI installé, app installée quand une session graphique existe,
# et session `op` active.
module_check() {
  pkg_installed 1password-cli || return 1
  if has_gui; then pkg_installed 1password || return 1; fi
  op_session_active
}

module_install() {
  apt_add_repo 1password "$OP_KEY_URL" "$OP_REPO_URL" stable main
  _op_install_debsig_policy
  if has_gui; then
    apt_install 1password-cli 1password
  else
    log_warn "Pas de session graphique : l'application de bureau 1Password est omise, seul le CLI est installé."
    apt_install 1password-cli
  fi
  log_ok "op $(op --version 2>/dev/null || echo '?')"
}

# Politique debsig-verify de 1Password (vérification de signature des .deb),
# idempotente : les fichiers ne sont réécrits que s'ils diffèrent.
_op_install_debsig_policy() {
  local tmp_pol tmp_key
  tmp_pol=$(mktemp -t 1password-pol.XXXXXX)
  tmp_key=$(mktemp -t 1password-debsig.XXXXXX)
  add_cleanup "rm -f '$tmp_pol' '$tmp_key'"
  run curl -fsSL "$OP_DEBSIG_POLICY_URL" -o "$tmp_pol" || return 1
  run sh -c "curl -fsSL '$OP_KEY_URL' | gpg --dearmor > '$tmp_key'" || return 1
  if ! cmp -s "$tmp_pol" "$OP_DEBSIG_POLICY"; then
    run_sudo install -m 0755 -d "$(dirname "$OP_DEBSIG_POLICY")" || return 1
    run_sudo install -m 0644 "$tmp_pol" "$OP_DEBSIG_POLICY" || return 1
  fi
  if ! cmp -s "$tmp_key" "$OP_DEBSIG_KEYRING"; then
    run_sudo install -m 0755 -d "$(dirname "$OP_DEBSIG_KEYRING")" || return 1
    run_sudo install -m 0644 "$tmp_key" "$OP_DEBSIG_KEYRING" || return 1
  fi
  log_ok "Politique debsig 1Password en place"
}

module_configure() {
  _op_connect || return 1
  _op_ssh_agent
}

# Connexion : rien à faire si une session est active ; sinon intégration avec
# l'app de bureau (si installée) puis, en repli ou sans app, `op account add` /
# `op signin`. Échec explicite si aucune session à la fin.
_op_connect() {
  if op_session_active; then
    log_ok "Session 1Password déjà active ($(op whoami 2>/dev/null | sed -n 's/^Email: *//p'))"
    return 0
  fi
  if pkg_installed 1password; then
    local err_file
    err_file=$(mktemp -t dotfiles-op-err.XXXXXX)
    add_cleanup "rm -f '$err_file'"
    log_info "Activer l'intégration entre l'application 1Password et le CLI :"
    log_info "  1. Ouvrir et déverrouiller l'application 1Password (Applications › 1Password)."
    log_info "  2. Settings › Security : activer « Unlock using system authentication »."
    log_info "  3. Settings › Developer : cocher « Integrate with 1Password CLI »."
    while true; do
      if ui_confirm "Intégration activée ? (op signin sera lancé ; autoriser la demande dans l'app)" oui; then
        # Avec l'intégration, c'est `op signin` qui déclenche la demande
        # d'autorisation dans l'app ; `op whoami` seul échoue tant qu'elle
        # n'a pas été accordée. Sortie standard ignorée : sans intégration, op
        # y écrirait un jeton de session (jamais journalisé).
        op signin >/dev/null 2>"$err_file" </dev/tty || true
        if op_session_active; then
          log_ok "Session 1Password active via l'application."
          return 0
        fi
        log_warn "Session toujours inactive : $(op whoami 2>&1 >/dev/null | head -1)"
        [[ -s $err_file ]] && log_warn "op signin : $(head -1 "$err_file")"
        ui_confirm "Réessayer ? (« Non » bascule sur la connexion en terminal)" oui || break
      else
        break
      fi
    done
    log_info "Connexion en terminal (op account add / op signin)."
  fi
  if ! op_signin_interactive; then
    log_error "Aucune session 1Password : les modules qui ont besoin de secrets seront sautés. Relancer « setup.sh 1password » pour réessayer."
    return 1
  fi
}

# Agent SSH de l'application (D8) : SSH_AUTH_SOCK dans la config shell commune,
# une seule fois ; l'activation dans l'app reste manuelle.
_op_ssh_agent() {
  pkg_installed 1password || return 0
  if ensure_line "$SHELL_COMMON_RC" "$OP_AGENT_SOCK_LINE"; then
    log_ok "SSH_AUTH_SOCK → agent 1Password ajouté dans $SHELL_COMMON_RC"
  else
    log_ok "SSH_AUTH_SOCK déjà configuré dans $SHELL_COMMON_RC"
  fi
  manual_step "Activer l'agent SSH dans 1Password : Settings › Developer › « Use the SSH agent », puis ouvrir un nouveau terminal."
}
