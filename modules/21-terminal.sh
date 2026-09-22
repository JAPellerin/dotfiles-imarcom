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
# charge lui-même et vérifie le résultat (design D4).
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
TERMINAL_GNOME_SCHEMA="org.gnome.desktop.default-applications.terminal"
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

# _terminal_is_default : vrai si l'alternative Debian désigne Ghostty. Sans effet
# de bord. Le réglage GNOME n'entre pas dans le critère : son schéma peut être
# absent (autre bureau) sans que le poste soit pour autant mal configuré.
_terminal_is_default() {
  [[ $(update-alternatives --query "$TERMINAL_ALT_NAME" 2>/dev/null \
       | sed -n 's/^Value: //p') == "$TERMINAL_BIN" ]]
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
# chemin est sans effet, donc idempotent) et le réglage propre à GNOME quand son
# schéma est là. Le résultat est vérifié : s'il ne se constate pas, l'étape est
# déclarée manuelle plutôt que tenue pour faite (D4).
_terminal_set_default() {
  if _terminal_is_default; then
    log_ok "Ghostty est déjà le terminal par défaut."
  else
    run_sudo update-alternatives --install "$TERMINAL_ALT_LINK" "$TERMINAL_ALT_NAME" "$TERMINAL_BIN" 50 || return 1
    run_sudo update-alternatives --set "$TERMINAL_ALT_NAME" "$TERMINAL_BIN" || return 1
  fi
  _terminal_set_gnome_default
  if _terminal_is_default; then
    log_ok "Terminal par défaut : $TERMINAL_BIN"
    return 0
  fi
  log_warn "Ghostty n'a pas pu être constaté comme terminal par défaut."
  manual_step "$TERMINAL_MANUAL"
}

# _terminal_set_gnome_default : réglage GNOME, sauté sans erreur quand gsettings
# ou le schéma manquent (autre bureau, WSL). Jamais bloquant : l'alternative
# Debian reste le critère de module_check.
_terminal_set_gnome_default() {
  command -v gsettings >/dev/null 2>&1 || return 0
  if ! gsettings list-schemas 2>/dev/null | grep -qx "$TERMINAL_GNOME_SCHEMA"; then
    log_info "Schéma GNOME « $TERMINAL_GNOME_SCHEMA » absent : réglage propre à GNOME sauté."
    return 0
  fi
  run gsettings set "$TERMINAL_GNOME_SCHEMA" exec "$TERMINAL_BIN" || return 0
  [[ $(gsettings get "$TERMINAL_GNOME_SCHEMA" exec 2>/dev/null) == "'$TERMINAL_BIN'" ]] \
    || log_warn "GNOME n'a pas retenu $TERMINAL_BIN comme terminal."
}
