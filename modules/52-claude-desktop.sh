#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/52-claude-desktop.sh — Claude Desktop (Linux, bêta) depuis le dépôt apt
# d'Anthropic, prêt pour Cowork (groupe kvm), connexion signalée au résumé.
#   https://code.claude.com/docs/en/desktop-linux
#
# Le paquet enregistre lui-même son dépôt (claude-desktop.list) sauf si
# /etc/default/claude-desktop le lui interdit : ce réglage est posé avant le
# paquet, et le dépôt déclaré par le socle (design D1, D2 — même mécanisme que
# /etc/default/google-chrome pour Chrome). Cowork fait tourner une VM QEMU/KVM :
# paquets QEMU en recommandations du paquet, utilisateur dans le groupe kvm (D3, D4).
# Voir openspec/changes/claude-desktop/specs/module-claude-desktop/spec.md et design.md.
MODULE_NAME="claude-desktop"
MODULE_DESC="Claude Desktop (dépôt apt Anthropic) ; Cowork (groupe kvm)"
MODULE_GROUP="apps"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

CLAUDE_DESKTOP_KEY_URL="https://downloads.claude.ai/claude-desktop/key.asc"
CLAUDE_DESKTOP_REPO_URL="https://downloads.claude.ai/claude-desktop/apt/stable"
CLAUDE_DESKTOP_DEFAULT_SRC="config/claude-desktop/claude-desktop.default"
# Racine surchargeable (tests), comme NAV_ETC pour le module navigateur.
CLAUDE_DESKTOP_ETC="${CLAUDE_DESKTOP_ETC:-}"
CLAUDE_DESKTOP_DEFAULT="$CLAUDE_DESKTOP_ETC/etc/default/claude-desktop"
CLAUDE_DESKTOP_GROUP="kvm"
CLAUDE_DESKTOP_LOGIN_MANUAL="Ouvrir Claude (menu des applications) et se connecter avec le compte Anthropic."

# Déjà fait = paquet installé, réglage anti-doublon en place avec le contenu
# attendu (le paquet le relit à chaque mise à jour), utilisateur membre de kvm
# dans la base des groupes (D5). Lu sans sudo ni réseau.
module_check() {
  pkg_installed claude-desktop || return 1
  cmp -s -- "$DOTFILES_DIR/$CLAUDE_DESKTOP_DEFAULT_SRC" "$CLAUDE_DESKTOP_DEFAULT" || return 1
  user_in_group "$CLAUDE_DESKTOP_GROUP"
}

# Réglage d'abord, puis dépôt, puis paquet avec ses recommandations (D1-D3).
# L'étape de connexion est déclarée ici et non dans module_configure : le runner
# lance chaque fonction dans son propre sous-shell, une variable « paquet absent
# avant » serait perdue en chemin ; manual_step écrit dans un fichier (D5).
module_install() {
  local fresh=0
  pkg_installed claude-desktop || fresh=1
  install_system_file "$CLAUDE_DESKTOP_DEFAULT_SRC" "$CLAUDE_DESKTOP_DEFAULT" || return 1
  apt_add_repo claude-desktop "$CLAUDE_DESKTOP_KEY_URL" "$CLAUDE_DESKTOP_REPO_URL" stable main || return 1
  apt_install claude-desktop || return 1
  if (( fresh == 1 )); then
    manual_step "$CLAUDE_DESKTOP_LOGIN_MANUAL"
  fi
}

# Cowork : utilisateur dans kvm, puis « rouvrir la session » tant que la session
# ne porte pas le groupe (D4). Aucune vérification de /dev/kvm : la
# virtualisation est une affaire de matériel, que l'application signale elle-même.
module_configure() {
  ensure_user_in_group "$CLAUDE_DESKTOP_GROUP" || return 1
  group_relogin_step "$CLAUDE_DESKTOP_GROUP"
}
