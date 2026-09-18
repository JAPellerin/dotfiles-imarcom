#!/usr/bin/env bash
# lib/core.sh — noyau du socle : chemins, journal, messages, sudo, nettoyage,
# détection d'environnement graphique.
#
# Chargé (« source ») par setup.sh et par les tests ; jamais exécuté directement.
# Ne touche pas aux options du shell : `set -euo pipefail` est posé par le runner.
# Voir openspec/changes/setup-socle/design.md (D3, D7, D9).

# --- Chemins et journal --------------------------------------------------------
# Toutes ces variables sont surchargeables avant le chargement (utile aux tests).
DOTFILES_DIR="${DOTFILES_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
DOTFILES_STATE_DIR="${DOTFILES_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles}"
LOG_FILE="${LOG_FILE:-$DOTFILES_STATE_DIR/setup-$(date +%Y%m%d-%H%M%S).log}"
export DOTFILES_DIR DOTFILES_STATE_DIR LOG_FILE

mkdir -p -- "$(dirname -- "$LOG_FILE")"
: >>"$LOG_FILE"

# --- Couleurs (seulement si stderr est un terminal et NO_COLOR absent) ----------
if [[ -t 2 && -z ${NO_COLOR:-} ]]; then
  _C_RESET=$'\033[0m' _C_BOLD=$'\033[1m' _C_DIM=$'\033[2m'
  _C_BLUE=$'\033[34m' _C_GREEN=$'\033[32m' _C_YELLOW=$'\033[33m'
  _C_RED=$'\033[31m' _C_MAGENTA=$'\033[35m'
else
  _C_RESET='' _C_BOLD='' _C_DIM='' _C_BLUE='' _C_GREEN='' _C_YELLOW='' _C_RED='' _C_MAGENTA=''
fi

# --- Messages : écran (stderr) ET journal ----------------------------------------
# Le journal reçoit une ligne horodatée sans couleur ; l'écran une ligne courte.
# stdout reste libre pour les données (op_read, gum choose, etc.).

# _log <NIVEAU> <symbole> <couleur> <message...>
_log() {
  local level=$1 symbol=$2 color=$3
  shift 3
  printf '[%s] %-5s %s\n' "$(date +%H:%M:%S)" "$level" "$*" >>"$LOG_FILE"
  printf '%s%s%s %s\n' "$color" "$symbol" "$_C_RESET" "$*" >&2
}

log_info()  { _log INFO  '→' "$_C_BLUE"   "$@"; }
log_ok()    { _log OK    '✔' "$_C_GREEN"  "$@"; }
log_warn()  { _log WARN  '⚠' "$_C_YELLOW" "$@"; }
log_error() { _log ERROR '✖' "$_C_RED"    "$@"; }

# log_step <titre> : titre de section (un module, une phase), en gras à l'écran.
log_step() {
  printf '\n[%s] ===== %s =====\n' "$(date +%H:%M:%S)" "$*" >>"$LOG_FILE"
  printf '\n%s%s%s\n' "$_C_BOLD" "$*" "$_C_RESET" >&2
}

# die <message> : erreur fatale, code de sortie 1.
die() {
  log_error "$@"
  exit 1
}

# --- Garde-fous --------------------------------------------------------------------
require_not_root() {
  if [[ $EUID -eq 0 ]]; then
    die "Ne pas lancer en root ni via sudo : lancer setup.sh avec votre compte utilisateur (le mot de passe sudo sera demandé une fois)."
  fi
}

# --- Nettoyage à la sortie -----------------------------------------------------------
# add_cleanup <commande> : enregistre une commande exécutée à la sortie du runner
# (arrêt du keepalive sudo, suppression de fichiers temporaires…).
# Les sous-shells `( … )` n'héritent pas du trap EXIT et copient la liste ; le
# garde-fou sur le propriétaire évite qu'un sous-shell passager (`$(…)`) nettoie
# à la place du processus principal. Un sous-shell durable qui enregistre ses
# propres nettoyages (module_call) ouvre sa portée avec cleanup_scope.
_CLEANUP_CMDS=()
_CLEANUP_OWNER=$BASHPID
add_cleanup() { _CLEANUP_CMDS+=("$*"); }
_run_cleanup() {
  [[ $BASHPID -eq $_CLEANUP_OWNER ]] || return 0
  local cmd
  for cmd in "${_CLEANUP_CMDS[@]}"; do
    eval "$cmd" || true
  done
}
trap _run_cleanup EXIT

# cleanup_scope : à appeler en tête d'un sous-shell `( … )` : repart d'une liste
# vide (celle du parent reste au parent) et rétablit le trap EXIT pour que les
# nettoyages enregistrés dans ce sous-shell s'exécutent à sa sortie.
cleanup_scope() {
  _CLEANUP_CMDS=()
  _CLEANUP_OWNER=$BASHPID
  trap _run_cleanup EXIT
}

# --- sudo : une seule saisie, ticket rafraîchi en tâche de fond (D3) --------------------
# La boucle est détachée de stdout/stderr (sinon `$(setup.sh …)` attendrait la
# fin du `sleep`) et tue son `sleep` en cours quand on l'arrête.
sudo_keepalive() {
  sudo -v || die "Impossible d'obtenir les droits sudo."
  (
    trap 'kill "${sleep_pid:-}" 2>/dev/null; exit 0' TERM
    while kill -0 "$$" 2>/dev/null; do
      sudo -n true 2>/dev/null
      sleep 60 & sleep_pid=$!
      wait "$sleep_pid"
    done
  ) >/dev/null 2>&1 &
  _SUDO_KEEPALIVE_PID=$!
  add_cleanup "kill $_SUDO_KEEPALIVE_PID 2>/dev/null"
  printf '[%s] INFO  sudo : ticket obtenu, keepalive pid %s\n' "$(date +%H:%M:%S)" "$_SUDO_KEEPALIVE_PID" >>"$LOG_FILE"
}

# --- Exécution journalisée (D7) -------------------------------------------------------------
# run <commande...> : exécute la commande avec stdout/stderr dans le journal et
# stdin fermé (aucune question interactive possible). En cas d'échec, affiche le
# code, les dernières lignes du journal et son chemin, puis renvoie le code.
# Sous ui_spin (_UI_SPINNING=1), l'affichage de l'échec est laissé au spinner.
run() {
  local rc=0
  printf '[%s] $ %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOG_FILE"
  "$@" >>"$LOG_FILE" 2>&1 </dev/null || rc=$?
  if (( rc != 0 )) && [[ -z ${_UI_SPINNING:-} ]]; then
    _run_report_failure "$rc" "$*"
  fi
  return "$rc"
}

# run_sudo <commande...> : idem avec sudo ; `-n` pour ne jamais bloquer sur une
# invite (le ticket est maintenu par sudo_keepalive).
run_sudo() { run sudo -n "$@"; }

# _run_report_failure <code> <description> : message d'échec + extrait du journal
# (les lignes depuis la dernière commande lancée par run, 20 au plus).
_run_report_failure() {
  local rc=$1 what=$2 extract
  extract=$(tac "$LOG_FILE" | sed '/^\[[0-9:]*\] \$ /q' | tac | tail -n 20)
  log_error "Échec (code $rc) : $what"
  printf '%s%s%s\n' "$_C_DIM" "$extract" "$_C_RESET" >&2
  printf '%sJournal complet : %s%s\n' "$_C_DIM" "$LOG_FILE" "$_C_RESET" >&2
}

# --- Fichiers de configuration --------------------------------------------------------------
# Config shell commune bash/zsh (POSIX uniquement), chargée par .bashrc et .zshrc.
SHELL_COMMON_RC="${SHELL_COMMON_RC:-$HOME/.commonrc}"

# ensure_line <fichier> <ligne> : ajoute la ligne (exacte) au fichier si elle n'y
# est pas déjà — idempotent, crée le fichier au besoin. Renvoie 0 si ajoutée,
# 1 si déjà présente (pour journaliser sans dupliquer).
ensure_line() {
  local file=$1 line=$2
  if [[ -f $file ]] && grep -qxF -- "$line" "$file"; then
    return 1
  fi
  mkdir -p -- "$(dirname -- "$file")"
  printf '%s\n' "$line" >>"$file"
}

# --- Environnement graphique (D9) -----------------------------------------------------------------
# has_gui : vrai si une session graphique est utilisable pour installer des apps
# de bureau. Faux d'office dans WSL : WSLg expose DISPLAY/WAYLAND_DISPLAY sans que
# la distribution soit un bureau cible.
has_gui() {
  [[ -n ${WSL_DISTRO_NAME:-} ]] && return 1
  case ${XDG_SESSION_TYPE:-} in
    x11|wayland) return 0 ;;
  esac
  [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]
}
