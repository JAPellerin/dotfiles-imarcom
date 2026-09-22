#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/21-terminal.sh — Ghostty depuis les dépôts d'Ubuntu, police MesloLGS NF
# pour Powerlevel10k, configuration versionnée, Ghostty comme terminal par défaut.
#
# Police : les quatre fichiers publiés par Powerlevel10k plutôt que l'archive
# Meslo des Nerd Fonts — 10 Mio contre 111, et surtout la famille « MesloLGS NF »
# que documente p10k, là où l'archive donne « MesloLGS Nerd Font » (design D1).
#   https://github.com/romkatv/powerlevel10k#manual-font-installation
# Terminal par défaut : le paquet ghostty n'enregistre aucune alternative
# x-terminal-emulator (constaté sur le .deb le 22 sept 2026), le module s'en
# charge lui-même. Et sur Ubuntu 26.04, GNOME ne nomme pas un terminal : sa clé
# « default-applications.terminal exec » vaut « xdg-terminal-exec », un script
# qui lit xdg-terminals.list (relevé en VM le 22 sept 2026). Le module écrit
# donc cette liste plutôt que d'écraser la délégation (design D4).
# Voir openspec/changes/terminal/specs/module-terminal/spec.md et design.md.
MODULE_NAME="terminal"
MODULE_DESC="Ghostty depuis les dépôts Ubuntu ; police MesloLGS NF ; config versionnée ; terminal par défaut"
MODULE_GROUP="shell"
MODULE_DEPS="base shell"
MODULE_NEEDS_GUI=1

TERMINAL_FONT_FAMILY="MesloLGS NF"
TERMINAL_FONT_DIR="MesloLGSNF"
TERMINAL_FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
TERMINAL_FONT_URLS=(
  "$TERMINAL_FONT_BASE/MesloLGS%20NF%20Regular.ttf"
  "$TERMINAL_FONT_BASE/MesloLGS%20NF%20Bold.ttf"
  "$TERMINAL_FONT_BASE/MesloLGS%20NF%20Italic.ttf"
  "$TERMINAL_FONT_BASE/MesloLGS%20NF%20Bold%20Italic.ttf"
)
TERMINAL_BIN="/usr/bin/ghostty"
TERMINAL_ALT_NAME="x-terminal-emulator"
TERMINAL_ALT_LINK="/usr/bin/x-terminal-emulator"
TERMINAL_DESKTOP="com.mitchellh.ghostty.desktop"
TERMINAL_XDG_LIST="$HOME/.config/xdg-terminals.list"
TERMINAL_CONFIG="config/terminal/ghostty"
TERMINAL_CONFIG_TARGET="$HOME/.config/ghostty/config"
TERMINAL_MANUAL="Faire de Ghostty le terminal par défaut dans les réglages du bureau : le script n'a pas pu le constater."

# Déjà fait = ghostty installé, police connue de fontconfig, configuration liée,
# alternative pointant sur Ghostty (D6). La police est constatée par fontconfig
# et non par la présence de fichiers : c'est lui qui décide si elle est utilisable.
module_check() {
  pkg_installed ghostty || return 1
  font_installed "$TERMINAL_FONT_FAMILY" || return 1
  config_linked "$TERMINAL_CONFIG" "$TERMINAL_CONFIG_TARGET" || return 1
  _terminal_is_default
}

# _terminal_is_default : vrai si les deux gestes sont en place. Sans effet de
# bord, donc utilisable par module_check.
_terminal_is_default() {
  _terminal_alt_ok && _terminal_xdg_ok
}

# L'alternative Debian, pour ce qui interroge x-terminal-emulator directement.
_terminal_alt_ok() {
  [[ $(update-alternatives --query "$TERMINAL_ALT_NAME" 2>/dev/null \
       | sed -n 's/^Value: //p') == "$TERMINAL_BIN" ]]
}

# La liste des terminaux de l'utilisateur, que xdg-terminal-exec consulte : seule
# la première entrée non vide compte, c'est le terminal préféré.
_terminal_xdg_ok() {
  [[ -f $TERMINAL_XDG_LIST ]] || return 1
  [[ $(grep -m1 -v '^[[:space:]]*$' "$TERMINAL_XDG_LIST" 2>/dev/null) == "$TERMINAL_DESKTOP" ]]
}

module_install() {
  apt_install ghostty || return 1
  install_font "$TERMINAL_FONT_FAMILY" "$TERMINAL_FONT_DIR" "${TERMINAL_FONT_URLS[@]}"
}

module_configure() {
  link_config "$TERMINAL_CONFIG" "$TERMINAL_CONFIG_TARGET" || return 1
  _terminal_set_default
}

# _terminal_set_default : deux gestes, parce que le paquet n'en fait aucun —
# l'alternative Debian (enregistrée puis sélectionnée ; réenregistrer le même
# chemin est sans effet, donc idempotent) et la liste des terminaux de
# l'utilisateur, que le bureau consulte par xdg-terminal-exec. Le résultat est
# vérifié : s'il ne se constate pas, l'étape est déclarée manuelle plutôt que
# tenue pour faite (D4).
_terminal_set_default() {
  if _terminal_alt_ok; then
    log_ok "Alternative x-terminal-emulator déjà sur Ghostty."
  else
    run_sudo update-alternatives --install "$TERMINAL_ALT_LINK" "$TERMINAL_ALT_NAME" "$TERMINAL_BIN" 50 || return 1
    run_sudo update-alternatives --set "$TERMINAL_ALT_NAME" "$TERMINAL_BIN" || return 1
  fi
  _terminal_set_xdg_default || return 1
  if _terminal_is_default; then
    log_ok "Terminal par défaut : $TERMINAL_BIN"
    return 0
  fi
  log_warn "Ghostty n'a pas pu être constaté comme terminal par défaut."
  manual_step "$TERMINAL_MANUAL"
}

# _terminal_set_xdg_default : place le fichier de bureau de Ghostty en tête de
# ~/.config/xdg-terminals.list. Les entrées déjà présentes sont conservées
# derrière, sans doublon : l'utilisateur garde ses terminaux de repli, Ghostty
# passe simplement devant. Fichier utilisateur, aucun sudo.
_terminal_set_xdg_default() {
  local tmp
  if _terminal_xdg_ok; then
    log_ok "Ghostty est déjà en tête de $TERMINAL_XDG_LIST"
    return 0
  fi
  mkdir -p -- "$(dirname -- "$TERMINAL_XDG_LIST")" || return 1
  tmp=$(mktemp) || return 1
  add_cleanup "rm -f '$tmp'"
  printf '%s\n' "$TERMINAL_DESKTOP" >"$tmp"
  if [[ -f $TERMINAL_XDG_LIST ]]; then
    grep -vxF -- "$TERMINAL_DESKTOP" "$TERMINAL_XDG_LIST" >>"$tmp" || true
  fi
  cp -f -- "$tmp" "$TERMINAL_XDG_LIST" || return 1
  log_ok "Ghostty en tête de $TERMINAL_XDG_LIST"
}
