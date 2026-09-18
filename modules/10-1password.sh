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
# Voir openspec/specs/module-1password/spec.md (parcours de connexion :
# openspec/changes/archive/2026-09-18-1password-integration-app/design.md).
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
  local tmp_pol tmp_asc tmp_key
  tmp_pol=$(mktemp -t 1password-pol.XXXXXX)
  tmp_asc=$(mktemp -t 1password-asc.XXXXXX)
  tmp_key=$(mktemp -t 1password-debsig.XXXXXX)
  add_cleanup "rm -f '$tmp_pol' '$tmp_asc' '$tmp_key'"
  run curl -fsSL "$OP_DEBSIG_POLICY_URL" -o "$tmp_pol" || return 1
  # Clé téléchargée puis convertie en deux étapes (un tube `curl | gpg` masquerait
  # l'échec de curl et installerait un trousseau vide).
  run curl -fsSL "$OP_KEY_URL" -o "$tmp_asc" || return 1
  run gpg --batch --yes --dearmor -o "$tmp_key" "$tmp_asc" || return 1
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

# Délais du parcours « intégration app » (surchargeables : tests) : durée d'un
# tour d'attente, intervalle de sondage, pause entre deux pages ouvertes (le
# temps que l'app démarre), stabilisation exigée avant `op signin`.
OP_WAIT_SECONDS="${OP_WAIT_SECONDS:-300}"
OP_WAIT_INTERVAL="${OP_WAIT_INTERVAL:-2}"
OP_OPEN_DELAY="${OP_OPEN_DELAY:-3}"
OP_SETTLE="${OP_SETTLE:-3}"
OP_CLI_CONFIG="${OP_CLI_CONFIG:-$HOME/.config/op/config}"

# Connexion : rien à faire si une session est active ; sinon intégration avec
# l'app de bureau (si installée), puis, sur demande ou sans app, `op account add` /
# `op signin` en terminal. Échec explicite si aucune session à la fin.
_op_connect() {
  local rc=0
  if op_session_active; then
    log_ok "Session 1Password déjà active ($(_op_email))"
    return 0
  fi
  if pkg_installed 1password; then
    _op_connect_via_app || rc=$?
    case $rc in
      0) return 0 ;;
      2) log_info "Connexion en terminal (op account add / op signin)." ;;
      *) _op_no_session; return 1 ;;
    esac
  fi
  op_signin_interactive || { _op_no_session; return 1; }
}

_op_no_session() {
  log_error "Aucune session 1Password : les modules qui ont besoin de secrets seront sautés. Relancer « setup.sh 1password » pour réessayer."
}

_op_email() { op whoami 2>/dev/null | sed -n 's/^Email: *//p'; }

# Parcours « intégration app » : lance l'app sur ses réglages, affiche la
# consigne une fois, attend que l'agent SSH et l'intégration CLI soient actifs
# (signaux lus sur disque, sans solliciter l'app : toute commande `op`
# déclencherait une demande d'autorisation), puis un seul `op signin`.
# Un lien profond ne fait naviguer l'app que lorsqu'il (r)ouvre sa fenêtre
# (vérifié en VM) : la page Developer reste un clic manuel dans la consigne.
# Si l'agent est déjà là (app configurée, simplement verrouillée), droit à
# `op signin`. Renvoie 0 = session active, 1 = abandon, 2 = terminal demandé.
_op_connect_via_app() {
  local err_file choice wait=1
  err_file=$(mktemp -t dotfiles-op-err.XXXXXX)
  add_cleanup "rm -f '$err_file'"
  if op_agent_ready; then
    log_info "Application 1Password déjà configurée (agent SSH actif) : déverrouillage via op signin."
    _op_try_signin "$err_file" && return 0
    wait=0   # l'agent est là : inutile de sonder, droit au menu de reprise
  else
    # Deux envois du lien Security : le premier lance l'app (écran de connexion,
    # lien ignoré), le second, reçu par l'app verrouillée, est exécuté quand la
    # fenêtre s'ouvre au déverrouillage — le réglage 2 est proposé dès la connexion.
    _op_open_settings security security
    log_info "Dans l'application 1Password qui vient de s'ouvrir :"
    log_info "  1. Se connecter (adresse du compte, courriel, Secret Key, mot de passe) si ce n'est pas déjà fait."
    log_info "  2. Settings › Security : cocher « Unlock using system authentication » (proposé dès la connexion)."
    log_info "  3. Dans les réglages, onglet Developer : cocher « Integrate with 1Password CLI »."
    log_info "  4. Même onglet : cocher « Use the SSH agent »."
    log_info "Le script reprend tout seul dès que les cases 3 et 4 sont cochées ; Ctrl-C pour abandonner."
  fi
  _OP_READY_SINCE=""
  while true; do
    if (( wait )) && ui_wait "En attente de l'intégration CLI et de l'agent SSH de 1Password" "$OP_WAIT_SECONDS" "$OP_WAIT_INTERVAL" _op_ready; then
      _op_try_signin "$err_file" && return 0
    fi
    wait=1
    choice=$(ui_choose "Pas encore de session 1Password. Que faire ?" \
      "Continuer d'attendre" \
      "Vérifier maintenant (op signin, même sans agent SSH)" \
      "Connexion en terminal (op account add / op signin, sans l'application)" \
      "Abandonner (les modules qui ont besoin de secrets seront sautés)") || return 1
    case $choice in
      Continuer*) ;;
      Vérifier*)  _op_try_signin "$err_file" && return 0 ;;
      Connexion*) return 2 ;;
      *)          return 1 ;;
    esac
  done
}

# Prêt quand l'intégration CLI et l'agent SSH sont actifs (lus sur disque) depuis
# au moins OP_SETTLE s d'affilée : un `op signin` lancé 0,2 s après le démarrage
# de l'agent a fait planter l'app (trap int3, VM du 18 sept), qui a alors perdu
# ses réglages et ses sockets ; 1 s et 60 s après, aucun problème.
# Sondée par wait_for dans le shell courant : _OP_READY_SINCE persiste
# (millisecondes via EPOCHREALTIME ; SECONDS n'a qu'une résolution d'une seconde).
_op_ready() {
  local now=$(( ${EPOCHREALTIME/./} / 1000 ))
  if op_app_cli_enabled && op_agent_ready; then
    : "${_OP_READY_SINCE:=$now}"
    (( now - _OP_READY_SINCE >= OP_SETTLE * 1000 ))
  else
    _OP_READY_SINCE=""
    return 1
  fi
}

# _op_open_settings <page...> : ouvre l'app sur onepassword://settings/<page>
# (liens profonds de la doc d'intégration ; le paquet enregistre le schéma
# onepassword://). Lancement détaché, sorties vers /dev/null : l'app hériterait
# sinon du journal et y écrirait ses propres logs tant qu'elle tourne (vu en VM).
# Échec non bloquant : la consigne donne aussi les menus.
_op_open_settings() {
  local page
  if ! command -v xdg-open >/dev/null 2>&1; then
    log_warn "xdg-open introuvable : ouvrir l'application 1Password à la main (Applications › 1Password)."
    return 0
  fi
  local i=0
  for page in "$@"; do
    # Pause entre deux envois seulement (le temps que l'app démarre).
    (( i++ == 0 )) || sleep "$OP_OPEN_DELAY"
    printf '[%s] $ xdg-open onepassword://settings/%s (détaché)\n' "$(date +%H:%M:%S)" "$page" >>"$LOG_FILE"
    setsid -f xdg-open "onepassword://settings/$page" >/dev/null 2>&1 </dev/null \
      || log_warn "Impossible d'ouvrir onepassword://settings/$page : aller dans les réglages de l'app à la main."
  done
}

# _op_try_signin <fichier-erreur> : un seul `op signin`. Avec l'intégration,
# c'est lui qui déclenche la demande d'autorisation dans l'app (`op whoami`
# seul échoue avant). stdin fermé (l'autorisation se fait dans l'app, pas au
# clavier) ; stdout ignoré (sans intégration, op y écrirait un jeton de session,
# jamais journalisé) ; stderr gardé pour le diagnostic.
_op_try_signin() {
  local err_file=$1
  if ! op_app_cli_enabled; then
    log_warn "« Integrate with 1Password CLI » n'est pas coché dans l'app (Settings › Developer) : op signin ne peut pas passer par l'application."
    return 1
  fi
  log_info "Vérification : op signin (autoriser la demande dans l'application)…"
  op signin >/dev/null 2>"$err_file" </dev/null || true
  if op_session_active; then
    log_ok "Session 1Password active via l'application ($(_op_email))."
    _op_warn_cli_account
    return 0
  fi
  if [[ -s $err_file ]]; then
    log_warn "Session toujours inactive : $(head -1 "$err_file")"
  else
    log_warn "Session toujours inactive."
  fi
  log_warn "Vérifier dans l'app : « Unlock using system authentication » (Settings › Security) et « Integrate with 1Password CLI » (Settings › Developer)."
  return 1
}

# Un compte ajouté au CLI (`op account add`, présent dans sa config) est inutile
# une fois l'intégration active et peut la perturber ; la doc recommande
# `op account forget --all`. Décision laissée à l'utilisateur.
_op_warn_cli_account() {
  if [[ -f $OP_CLI_CONFIG ]] && grep -q '"shorthand"' "$OP_CLI_CONFIG" 2>/dev/null; then
    log_warn "Un compte ajouté au CLI subsiste dans $OP_CLI_CONFIG ; avec l'intégration app il est inutile : « op account forget --all » pour le retirer."
  fi
}

# Agent SSH de l'application (D8) : SSH_AUTH_SOCK dans la config shell commune,
# une seule fois. L'activation a été obtenue dans _op_connect ; on constate.
_op_ssh_agent() {
  pkg_installed 1password || return 0
  if ensure_line "$SHELL_COMMON_RC" "$OP_AGENT_SOCK_LINE"; then
    log_ok "SSH_AUTH_SOCK → agent 1Password ajouté dans $SHELL_COMMON_RC"
  else
    log_ok "SSH_AUTH_SOCK déjà configuré dans $SHELL_COMMON_RC"
  fi
  if op_agent_ready; then
    log_info "Agent SSH 1Password actif ; SSH_AUTH_SOCK prend effet dans un nouveau terminal."
  else
    log_warn "Agent SSH 1Password inactif (« Use the SSH agent » non coché ou app fermée) : SSH_AUTH_SOCK ne servira qu'une fois l'agent activé."
  fi
}
