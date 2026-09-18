#!/usr/bin/env bash
# bootstrap.sh — installation en une ligne sur une Ubuntu 26.04 vierge :
#
#   curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | bash
#
# 1. installe git et gum (dépôts Ubuntu) s'ils manquent ;
# 2. clone le dépôt public en HTTPS dans ~/dotfiles (ou le met à jour) ;
# 3. passe la main à setup.sh, l'entrée standard rattachée au terminal pour que
#    les menus fonctionnent malgré le lancement par `curl | bash` (design D2).
#
# Script autonome : n'utilise rien du dépôt (pas encore cloné) ni gum (pas encore
# installé). Tourne avec le compte utilisateur ; sudo n'est demandé que pour apt.
# Voir openspec/specs/bootstrap/spec.md.
set -euo pipefail

REPO_URL="https://github.com/JAPellerin/dotfiles-imarcom.git"
RAW_URL="https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

STEP="démarrage"
trap 'echo "✖ Échec à l'"'"'étape « $STEP ». Relancer : curl -fsSL $RAW_URL/bootstrap.sh | bash" >&2' ERR

if [ "$(id -u)" -eq 0 ]; then
  echo "✖ Ne pas lancer en root ni via sudo : lancer avec votre compte utilisateur." >&2
  exit 1
fi

STEP="[1/3] prérequis (git, gum)"
echo "$STEP"
missing=()
for tool in git gum; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "  installation de : ${missing[*]}"
  sudo apt-get update -q
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${missing[@]}"
else
  echo "  déjà installés"
fi

STEP="[2/3] dépôt $DOTFILES_DIR"
echo "$STEP"
if [ ! -e "$DOTFILES_DIR" ]; then
  git clone --quiet "$REPO_URL" "$DOTFILES_DIR"
  echo "  cloné depuis $REPO_URL"
elif git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  origin=$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null || true)
  case $origin in
    *JAPellerin/dotfiles-imarcom*) ;;
    *) echo "✖ $DOTFILES_DIR est un dépôt git étranger (origin : ${origin:-aucun}). Le déplacer ou choisir DOTFILES_DIR=<autre dossier>." >&2; exit 1 ;;
  esac
  git -C "$DOTFILES_DIR" pull --quiet --ff-only
  echo "  mis à jour (git pull)"
else
  echo "✖ $DOTFILES_DIR existe mais n'est pas un dépôt git : rien n'a été écrasé. Le déplacer ou choisir DOTFILES_DIR=<autre dossier>." >&2
  exit 1
fi

STEP="[3/3] lancement de setup.sh"
echo "$STEP"
# Lancé par `curl | bash`, stdin est le tube : on rattache le terminal si possible.
if ( : </dev/tty ) 2>/dev/null; then
  exec bash "$DOTFILES_DIR/setup.sh" "$@" </dev/tty
else
  exec bash "$DOTFILES_DIR/setup.sh" "$@"
fi
