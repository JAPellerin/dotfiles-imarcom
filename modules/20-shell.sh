#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/20-shell.sh — zsh + oh-my-zsh + Powerlevel10k + plugins, fichiers de
# config du dépôt liés dans ~ (config/shell/), zsh comme shell de connexion.
#
# Procédures officielles suivies (clonage git plutôt que les installateurs) :
#   oh-my-zsh : https://github.com/ohmyzsh/ohmyzsh#manual-installation
#   p10k      : https://github.com/romkatv/powerlevel10k#oh-my-zsh
#   plugins   : https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh
#               https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh
# Voir openspec/specs/module-shell/spec.md et openspec/specs/config-files/spec.md.
MODULE_NAME="shell"
MODULE_DESC="zsh + oh-my-zsh + Powerlevel10k + plugins ; .zshrc .commonrc .p10k.zsh liés depuis le dépôt"
MODULE_GROUP="shell"
MODULE_DEPS="base"

SHELL_ZSH_DIR="$HOME/.oh-my-zsh"
SHELL_ZSH_CUSTOM="$SHELL_ZSH_DIR/custom"
# nom|url|dossier|options de clone (oh-my-zsh complet : `omz update` en a besoin)
SHELL_REPOS=(
  "oh-my-zsh|https://github.com/ohmyzsh/ohmyzsh.git|$SHELL_ZSH_DIR|"
  "powerlevel10k|https://github.com/romkatv/powerlevel10k.git|$SHELL_ZSH_CUSTOM/themes/powerlevel10k|--depth=1"
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git|$SHELL_ZSH_CUSTOM/plugins/zsh-autosuggestions|--depth=1"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git|$SHELL_ZSH_CUSTOM/plugins/zsh-syntax-highlighting|--depth=1"
)
# fichier du dépôt|cible dans ~
SHELL_LINKS=(
  "config/shell/zshrc|$HOME/.zshrc"
  "config/shell/commonrc|$SHELL_COMMON_RC"
  "config/shell/p10k.zsh|$HOME/.p10k.zsh"
)
SHELL_BASHRC="$HOME/.bashrc"
SHELL_BASHRC_EXTRA="$DOTFILES_DIR/config/shell/bashrc-extra.sh"
SHELL_BASHRC_LINE="[ -r \"$SHELL_BASHRC_EXTRA\" ] && . \"$SHELL_BASHRC_EXTRA\"   # dotfiles : commonrc, nvm, branche git"

# Déjà fait = zsh installé, quatre dépôts présents, trois liens en place, ligne
# bash posée, zsh shell de connexion. Tout est constaté, rien n'est mémorisé.
module_check() {
  local entry rel target
  pkg_installed zsh || return 1
  for entry in "${SHELL_REPOS[@]}"; do
    IFS='|' read -r _ _ target _ <<<"$entry"
    [[ -d $target/.git ]] || return 1
  done
  for entry in "${SHELL_LINKS[@]}"; do
    IFS='|' read -r rel target <<<"$entry"
    config_linked "$rel" "$target" || return 1
  done
  [[ -f $SHELL_BASHRC ]] && grep -qxF -- "$SHELL_BASHRC_LINE" "$SHELL_BASHRC" || return 1
  _shell_login_is_zsh
}

_shell_login_is_zsh() {
  [[ $(getent passwd "$USER" | cut -d: -f7) == "$(command -v zsh)" ]]
}

module_install() {
  local entry name url target opts
  apt_install zsh || return 1
  for entry in "${SHELL_REPOS[@]}"; do
    IFS='|' read -r name url target opts <<<"$entry"
    # shellcheck disable=SC2086  # opts : options de clone séparées par des espaces, volontairement éclatées
    ui_spin "Dépôt $name" ensure_git_clone "$url" "$target" $opts || return 1
  done
}

module_configure() {
  local entry rel target
  for entry in "${SHELL_LINKS[@]}"; do
    IFS='|' read -r rel target <<<"$entry"
    link_config "$rel" "$target" || return 1
  done
  # bash : le .bashrc d'Ubuntu reste intact, une seule ligne charge le complément.
  if ensure_line "$SHELL_BASHRC" "$SHELL_BASHRC_LINE"; then
    log_ok "Complément bash chargé depuis $SHELL_BASHRC ($SHELL_BASHRC_EXTRA)"
  else
    log_ok "Complément bash déjà chargé par $SHELL_BASHRC"
  fi
  # Anciens ajouts manuels (WSL de développement) : doublon inoffensif, à nettoyer.
  if grep -v -F -- "$SHELL_BASHRC_EXTRA" "$SHELL_BASHRC" | grep -qE 'commonrc|git-sh-prompt'; then
    log_warn "$SHELL_BASHRC contient encore d'anciens ajouts manuels (.commonrc, git-sh-prompt) : doublon inoffensif, à retirer à la main."
  fi
  if _shell_login_is_zsh; then
    log_ok "zsh est déjà le shell de connexion."
  else
    run_sudo chsh -s "$(command -v zsh)" "$USER" || return 1
    log_ok "zsh défini comme shell de connexion : effectif à la prochaine session."
  fi
  log_info "Powerlevel10k attend une police Nerd Font dans le terminal (module « terminal ») ; sans elle, certains glyphes s'affichent mal."
}
