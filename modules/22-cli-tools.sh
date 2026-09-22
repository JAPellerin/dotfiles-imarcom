#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/22-cli-tools.sh — trousse de ligne de commande du quotidien, entièrement
# depuis les dépôts d'Ubuntu (aucun dépôt tiers, aucun téléchargement) :
# recherche dans le code (ripgrep), recherche de fichiers (fd), filtrage
# interactif (fzf), lecture colorée (bat), navigation (zoxide), git en terminal
# (lazygit) et client PostgreSQL.
#
# bat et fd s'installent sous les noms `batcat` et `fdfind` — collision de noms
# annoncée dans la description des paquets Debian. Le module rétablit les noms
# usuels par des liens dans ~/.local/bin, et non par des alias : l'aperçu de fzf
# appelle `bat` dans un sous-processus non interactif, où un alias n'existe pas
# (design D1). ~/.local/bin est mis en tête du PATH par config/shell/commonrc.
#
# Dépend de `shell` et pas seulement de `base` (D7) : sans lui, ~/.commonrc
# n'existe pas, le fragment déposé ici n'est jamais chargé, et les initialisations
# de fzf et zoxide — qui vivent dans zshrc et bashrc-extra.sh — non plus.
# Voir openspec/changes/cli-tools/specs/module-cli-tools/spec.md et design.md.
MODULE_NAME="cli-tools"
MODULE_DESC="trousse CLI : ripgrep / fd / fzf / bat / zoxide / lazygit / client PostgreSQL"
MODULE_GROUP="shell"
MODULE_DEPS="base shell"

CLI_TOOLS_PACKAGES=(ripgrep fd-find fzf bat zoxide lazygit postgresql-client)
# commande réellement installée|nom usuel rétabli dans ~/.local/bin
CLI_TOOLS_RENAMED=(
  "batcat|bat"
  "fdfind|fd"
)
CLI_TOOLS_BIN_DIR="$HOME/.local/bin"
CLI_TOOLS_FRAGMENT="config/cli-tools/commonrc.sh"
CLI_TOOLS_FRAGMENT_TARGET="$SHELL_COMMON_RC_DIR/cli-tools.sh"

# Déjà fait = les sept paquets installés, les deux noms usuels rétablis, le
# fragment lié. Tout est constaté, rien n'est mémorisé (D5). Les lignes de
# bashrc-extra.sh ne sont pas vérifiées ici : ce fichier appartient au module
# `shell`, dont le module_check couvre déjà son lien.
module_check() {
  local pkg entry real usual
  for pkg in "${CLI_TOOLS_PACKAGES[@]}"; do
    pkg_installed "$pkg" || return 1
  done
  for entry in "${CLI_TOOLS_RENAMED[@]}"; do
    IFS='|' read -r real usual <<<"$entry"
    _cli_tools_link_ok "$real" "$usual" || return 1
  done
  config_linked "$CLI_TOOLS_FRAGMENT" "$CLI_TOOLS_FRAGMENT_TARGET"
}

# _cli_tools_link_ok <commande installée> <nom usuel> : vrai si le nom usuel est
# déjà le lien attendu vers le binaire du système. Sans effet de bord.
_cli_tools_link_ok() {
  local target="$CLI_TOOLS_BIN_DIR/$2" src
  src=$(command -v "$1" 2>/dev/null) || return 1
  [[ -L $target ]] || return 1
  [[ $(readlink -f -- "$target") == "$(readlink -f -- "$src")" ]]
}

module_install() {
  apt_install "${CLI_TOOLS_PACKAGES[@]}"
}

module_configure() {
  local entry real usual
  for entry in "${CLI_TOOLS_RENAMED[@]}"; do
    IFS='|' read -r real usual <<<"$entry"
    _cli_tools_rename "$real" "$usual" || return 1
  done
  link_config "$CLI_TOOLS_FRAGMENT" "$CLI_TOOLS_FRAGMENT_TARGET"
}

# _cli_tools_rename <commande installée> <nom usuel> : crée
# ~/.local/bin/<nom usuel> → binaire du système. La cible est résolue par
# `command -v` plutôt qu'écrite en dur : le chemin appartient au paquet (D2).
#   lien déjà bon               → rien
#   fichier ou lien étranger    → laissé intact et signalé (D1) : le poste peut
#                                 avoir un vrai binaire installé à la main, et
#                                 l'écraser serait une perte silencieuse
#   commande introuvable        → échec nommé (le paquet a changé de forme)
_cli_tools_rename() {
  local real=$1 usual=$2 src
  local target="$CLI_TOOLS_BIN_DIR/$usual"
  if ! src=$(command -v "$real" 2>/dev/null); then
    log_error "Commande introuvable après installation : $real — le paquet a-t-il changé de forme ?"
    return 1
  fi
  if _cli_tools_link_ok "$real" "$usual"; then
    log_ok "Déjà en place : $target → $src"
    return 0
  fi
  if [[ -e $target || -L $target ]]; then
    # Rien n'est écrasé (D1), mais le module se terminera « fait » alors que
    # module_check dira « à faire » : sans étape manuelle, l'écart ne se voit
    # que dans le journal qui a défilé.
    log_warn "$target existe et ne pointe pas vers $src : laissé intact."
    manual_step "Retirer $target (il ne pointe pas vers $src), puis relancer ./setup.sh cli-tools pour disposer de « $usual »."
    return 0
  fi
  mkdir -p -- "$CLI_TOOLS_BIN_DIR" || return 1
  ln -sfn -- "$src" "$target" || return 1
  log_ok "Lien créé : $target → $src"
}
