#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/42-dev-tools.sh — outils en ligne de commande du travail quotidien :
# Claude Code et la CLI Atlassian Teamwork Graph (twg), par les installateurs
# officiels de leurs éditeurs, pour l'utilisateur courant (~/.local/bin).
#   Claude Code : https://code.claude.com/docs/en/setup (installateur natif, recommandé)
#   twg         : https://developer.atlassian.com/platform/teamwork-graph/twg-cli/getting-started/installation/
#
# Aucun des deux ne passe par npm : pas de dépendance à `node` (design D7).
# L'installateur de twg ajoute un `export PATH=…` à ~/.zshrc — un lien vers le
# dépôt — quand ~/.local/bin manque au PATH : le module l'y met avant (D2).
# Les connexions restent des gestes de l'utilisateur, signalés au résumé (D5).
# Voir openspec/specs/module-dev-tools/spec.md et openspec/changes/archive/2026-09-23-dev-tools/design.md.
MODULE_NAME="dev-tools"
MODULE_DESC="Claude Code (installateur natif) ; twg (CLI Atlassian Teamwork Graph)"
MODULE_GROUP="dev"
MODULE_DEPS="base shell"

DEV_TOOLS_BIN_DIR="$HOME/.local/bin"
DEV_TOOLS_CLAUDE_URL="https://claude.ai/install.sh"
DEV_TOOLS_TWG_URL="https://teamwork-graph.atlassian.com/cli/install"
# Conditions d'utilisation acceptées par le script (décision de l'utilisateur,
# 23 sept 2026), sans connexion ni skills ajoutées aux agents (D4).
DEV_TOOLS_TWG_ARGS=(--yes --skip-login --skip-skills)
# Fichiers dont la seule présence dit qu'une connexion a été faite (D5) ; leur
# contenu n'est jamais lu.
DEV_TOOLS_CLAUDE_AUTH="$HOME/.claude/.credentials.json"
DEV_TOOLS_TWG_AUTH="$HOME/.config/twg/auth_oauth.conf"
DEV_TOOLS_CLAUDE_MANUAL="Connecter Claude Code : lancer « claude » et suivre la connexion dans le navigateur."
DEV_TOOLS_TWG_MANUAL="Connecter twg à Atlassian : lancer « twg login » (navigateur, choix du site)."

# Déjà fait = les deux commandes installées et exécutables (D6). `-x` suit le
# lien ~/.local/bin/claude : un lien cassé compte comme absent. Les connexions
# n'y entrent pas.
module_check() {
  [[ -x $DEV_TOOLS_BIN_DIR/claude && -x $DEV_TOOLS_BIN_DIR/twg ]]
}

# _dev_tools_path : ~/.local/bin créé et mis en tête du PATH pour la durée du
# module, s'il n'y est pas déjà — sans quoi l'installateur de twg l'ajouterait
# lui-même dans ~/.zshrc (D2).
_dev_tools_path() {
  mkdir -p -- "$DEV_TOOLS_BIN_DIR" || return 1
  case ":$PATH:" in
    *":$DEV_TOOLS_BIN_DIR:"*) ;;
    *) export PATH="$DEV_TOOLS_BIN_DIR:$PATH" ;;
  esac
}

# _dev_tools_run_installer <titre> <url> [args...] : télécharge l'installateur
# dans un temporaire, puis l'exécute par bash, sortie au journal (D1). Un
# téléchargement raté échoue en nommant l'URL, au lieu de faire exécuter une
# page d'erreur à bash comme le ferait `curl … | bash`.
_dev_tools_run_installer() {
  local title=$1 url=$2 tmp
  shift 2
  tmp=$(mktemp -t dev-tools-installer.XXXXXX) || return 1
  add_cleanup "rm -f '$tmp'"
  run curl -fsSL --retry 2 "$url" -o "$tmp" \
    || { log_error "Installateur introuvable : $url"; return 1; }
  ui_spin "$title" run bash "$tmp" "$@"
}

# Chaque outil seulement s'il manque : une installation existante n'est ni
# réinstallée ni mise à jour — Claude Code se met à jour seul, twg par `twg update`.
module_install() {
  _dev_tools_path || return 1
  if [[ -x $DEV_TOOLS_BIN_DIR/claude ]]; then
    log_ok "Claude Code déjà installé : $DEV_TOOLS_BIN_DIR/claude"
  else
    # Sans argument : le canal de la doc (D3).
    _dev_tools_run_installer "Claude Code (installateur natif)" "$DEV_TOOLS_CLAUDE_URL" || return 1
  fi
  if [[ -x $DEV_TOOLS_BIN_DIR/twg ]]; then
    log_ok "twg déjà installé : $DEV_TOOLS_BIN_DIR/twg"
  else
    # L'installateur lit /dev/tty lui-même : sans --yes, il attend l'acceptation
    # des conditions d'Atlassian sur le terminal, sans fin (vu en VM le 23 sept
    # 2026). --yes n'est transmis qu'avec --skip-login et --skip-skills (D4).
    _dev_tools_run_installer "twg (installateur Atlassian)" "$DEV_TOOLS_TWG_URL" "${DEV_TOOLS_TWG_ARGS[@]}" || return 1
  fi
  # L'installateur a pu réussir sans poser la commande attendue : constaté ici.
  local tool
  for tool in claude twg; do
    [[ -x $DEV_TOOLS_BIN_DIR/$tool ]] \
      || { log_error "$tool introuvable dans $DEV_TOOLS_BIN_DIR après son installateur."; return 1; }
  done
}

# Connexions : constatées par la présence d'un fichier, signalées au résumé final
# sinon (D5). Jamais d'échec : c'est un geste de l'utilisateur.
module_configure() {
  if [[ ! -e $DEV_TOOLS_CLAUDE_AUTH ]]; then
    manual_step "$DEV_TOOLS_CLAUDE_MANUAL"
  fi
  if [[ ! -e $DEV_TOOLS_TWG_AUTH ]]; then
    manual_step "$DEV_TOOLS_TWG_MANUAL"
  fi
  return 0
}
