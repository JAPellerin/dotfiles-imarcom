#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/51-vscode.sh — VS Code depuis le dépôt apt de Microsoft, trousseau GNOME
# pour ses jetons, et les extensions de config/vscode/extensions.txt.
#   https://code.visualstudio.com/docs/setup/linux (installation manuelle du dépôt)
#
# Le paquet `code` sait déclarer lui-même son dépôt : sa question debconf
# `code/add-microsoft-repo` est réglée à « non » avant l'installation, pour que
# seul le socle le déclare (design D2 — même piège que Chrome et repo_add_once).
# Pas de settings.json versionné : VS Code le réécrit depuis son interface.
# Voir openspec/changes/vscode/specs/module-vscode/spec.md et design.md.
MODULE_NAME="vscode"
MODULE_DESC="VS Code (dépôt Microsoft) ; gnome-keyring ; extensions versionnées"
MODULE_GROUP="apps"
MODULE_DEPS="base"
MODULE_NEEDS_GUI=1

VSCODE_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
VSCODE_REPO_URL="https://packages.microsoft.com/repos/code"
VSCODE_PACKAGES=(code gnome-keyring)
VSCODE_DEBCONF="code code/add-microsoft-repo boolean false"
VSCODE_EXTENSIONS_FILE="$DOTFILES_DIR/config/vscode/extensions.txt"
# Chemin du paquet plutôt que `code` du PATH : dans la WSL, `code` est celui de
# Windows (D5).
VSCODE_BIN="${VSCODE_BIN:-/usr/bin/code}"
# Connexion de l'extension Atlassian : OAuth dans le navigateur, jetons dans le
# stockage de secrets de VS Code — rien de scriptable, étape manuelle (D6b).
VSCODE_ATLASSIAN_MANUAL="Connecter Jira et Bitbucket dans VS Code : extension Atlassian (barre latérale) → se connecter, dans le navigateur."

# Déjà fait = les deux paquets installés et chaque extension de la liste
# présente (D4). `code --list-extensions` est la seule source de vérité des
# extensions ; il n'est lancé que si les paquets sont là.
module_check() {
  local pkg id
  for pkg in "${VSCODE_PACKAGES[@]}"; do
    pkg_installed "$pkg" || return 1
  done
  local installed
  installed=$(_vscode_installed) || return 1
  while IFS= read -r id; do
    grep -qxF -- "$id" <<<"$installed" || return 1
  done < <(_vscode_wanted)
}

# _vscode_wanted : identifiants de la liste, en minuscules, sans commentaires ni
# lignes vides.
_vscode_wanted() {
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$VSCODE_EXTENSIONS_FILE" | grep -v '^$' | tr '[:upper:]' '[:lower:]'
}

# _vscode_installed : extensions installées, en minuscules (D3 : l'éditeur
# affiche parfois « Anthropic.Claude-Code » pour « anthropic.claude-code »).
_vscode_installed() {
  "$VSCODE_BIN" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

# L'étape de connexion Atlassian est déclarée ici, seulement quand `code` vient
# d'être installé — la connexion se fait une fois et son état n'est pas lisible
# (D6b). Pas plus tard, dans module_configure : le runner lance les deux
# fonctions dans des sous-shells distincts, une variable posée ici y serait perdue.
module_install() {
  local fresh=0
  pkg_installed code || fresh=1
  _vscode_debconf || return 1
  apt_add_repo vscode "$VSCODE_KEY_URL" "$VSCODE_REPO_URL" stable main || return 1
  apt_install "${VSCODE_PACKAGES[@]}" || return 1
  if (( fresh == 1 )); then
    manual_step "$VSCODE_ATLASSIAN_MANUAL"
  fi
}

# _vscode_debconf : sélection écrite dans un fichier puis passée en argument, et
# non par un tube — `run` branche l'entrée sur /dev/null, la sélection
# n'atteindrait jamais debconf-set-selections, qui réussirait sans rien régler (D2).
_vscode_debconf() {
  local tmp
  tmp=$(mktemp -t vscode-debconf.XXXXXX) || return 1
  add_cleanup "rm -f '$tmp'"
  printf '%s\n' "$VSCODE_DEBCONF" >"$tmp"
  chmod 0644 "$tmp"
  run_sudo debconf-set-selections "$tmp"
}

# Extensions manquantes seulement, une à une ; un échec arrête le module en
# nommant l'extension, la relance ne refera que celles qui manquent (D3). En
# utilisateur, jamais sudo : VS Code refuse de tourner en root.
module_configure() {
  local installed id
  installed=$(_vscode_installed) || installed=""
  while IFS= read -r id; do
    if grep -qxF -- "$id" <<<"$installed"; then
      continue
    fi
    ui_spin "Extension VS Code : $id" run "$VSCODE_BIN" --install-extension "$id" \
      || { log_error "Extension VS Code non installée : $id"; return 1; }
  done < <(_vscode_wanted)
  log_ok "Extensions VS Code : $(_vscode_wanted | wc -l) présentes."
}
