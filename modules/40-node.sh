#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/40-node.sh — Node.js par nvm : la LTS du moment et la 26 (celle des
# projets, version par défaut), pnpm 11 sous chacune, openspec sous la 26.
#
# nvm est cloné à une étiquette fixée, selon la méthode « Git Install » de sa doc
# — son script d'installation ajouterait des lignes à ~/.zshrc, qui est un lien
# vers config/shell/zshrc (design D1). Le chargement de nvm dans les shells est
# déjà assuré par config/shell/commonrc, qui appartient au module `shell`.
#   https://github.com/nvm-sh/nvm#git-install
# pnpm 11 et non 12 : pnpm n'a pas de LTS, la 11 est maintenue et c'est celle
# des projets ; pnpm bascule de lui-même sur le champ `packageManager` d'un projet.
# Voir openspec/specs/module-node/spec.md et openspec/changes/archive/2026-09-23-node/design.md.
MODULE_NAME="node"
MODULE_DESC="Node.js par nvm : LTS et 26 (par défaut) ; pnpm 11 ; openspec"
MODULE_GROUP="dev"
MODULE_DEPS="base shell"

NODE_NVM_URL="https://github.com/nvm-sh/nvm.git"
NODE_NVM_TAG="v0.40.8"
NODE_NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NODE_MAJOR="26"
NODE_PNPM_MAJOR="11"
NODE_OPENSPEC_PKG="@fission-ai/openspec"

# Déjà fait = nvm présent ; la LTS connue localement et une 26 installées ; la
# version par défaut est une 26 ; pnpm 11 sous les deux ; openspec sous la 26
# (D5). Tout se lit sur disque ou par `nvm version`, qui lit les alias locaux :
# ni réseau ni sudo. Un poste plus ancien mais complet est « déjà fait ».
module_check() {
  local lts v26 def
  [[ -s $NODE_NVM_DIR/nvm.sh ]] || return 1
  { read -r lts; read -r v26; read -r def; } < <(_node_versions) || return 1
  [[ $lts == v* && $v26 == v* && $def == "v$NODE_MAJOR."* ]] || return 1
  _node_pnpm_ok "$lts" && _node_pnpm_ok "$v26" && _node_openspec_ok "$v26"
}

# _node_versions : trois lignes — versions installées qui répondent à `lts/*`,
# à la 26 et à l'alias `default` (« N/A » si aucune). Un seul bash enfant pour
# les trois : charger nvm.sh coûte ~0,2 s.
_node_versions() {
  NVM_DIR="$NODE_NVM_DIR" bash -c '. "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || exit 1
    nvm version "lts/*"; nvm version "$1"; nvm version default' _ "$NODE_MAJOR" 2>/dev/null
}

# _node_version <version> : la version installée qui y répond, ou « N/A ».
_node_version() {
  NVM_DIR="$NODE_NVM_DIR" bash -c '. "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || exit 1
    nvm version "$1"' _ "$1" 2>/dev/null
}

# _node_global_version <version de node> <paquet> : version du paquet global
# installé sous cette version de Node, lue dans son package.json (D4).
_node_global_version() {
  local pkg_json="$NODE_NVM_DIR/versions/node/$1/lib/node_modules/$2/package.json"
  [[ -f $pkg_json ]] || return 1
  jq -r '.version // empty' "$pkg_json" 2>/dev/null
}

_node_pnpm_ok() {
  local v
  v=$(_node_global_version "$1" pnpm) || return 1
  [[ $v == "$NODE_PNPM_MAJOR."* ]]
}

_node_openspec_ok() {
  _node_global_version "$1" "$NODE_OPENSPEC_PKG" >/dev/null
}

# _node_nvm <args...> : nvm dans un bash enfant, sortie au journal (D2). nvm est
# une fonction qui modifie le PATH de l'appelant : le runner garde le sien.
_node_nvm() {
  # shellcheck disable=SC2016  # développé par le bash enfant, pas ici
  run env NVM_DIR="$NODE_NVM_DIR" bash -c '. "$NVM_DIR/nvm.sh" && nvm "$@"' nvm "$@"
}

# nvm, puis les deux versions (D1, D3). `nvm install --lts` reste inconditionnel :
# c'est lui qui rafraîchit l'alias lts/* local, donc qui fait suivre la LTS du
# moment. La 26 n'est installée que s'il n'y en a aucune : `nvm install 26`
# téléchargerait sinon la dernière 26 publiée même quand une 26 est déjà là.
module_install() {
  ensure_git_clone "$NODE_NVM_URL" "$NODE_NVM_DIR" --branch "$NODE_NVM_TAG" --depth 1 || return 1
  ui_spin "Node LTS (nvm install --lts)" _node_nvm install --lts || return 1
  if [[ $(_node_version "$NODE_MAJOR") != v* ]]; then
    ui_spin "Node $NODE_MAJOR (nvm install $NODE_MAJOR)" _node_nvm install "$NODE_MAJOR" || return 1
  fi
}

# Version par défaut, puis outils globaux par version (D3, D4). Les versions
# effectives sont relues : si la LTS est devenue la 26, une seule est traitée.
module_configure() {
  local lts v26 def v
  { read -r lts; read -r v26; read -r def; } < <(_node_versions)
  if [[ ${lts:-} != v* || ${v26:-} != v* ]]; then
    log_error "nvm ne trouve pas les versions attendues (LTS : ${lts:-?}, $NODE_MAJOR : ${v26:-?})."
    return 1
  fi
  if [[ ${def:-} == "v$NODE_MAJOR."* ]]; then
    log_ok "Version par défaut : $def"
  else
    _node_nvm alias default "$NODE_MAJOR" || return 1
    log_ok "Version par défaut : Node $NODE_MAJOR ($v26)"
  fi
  for v in $(printf '%s\n' "$lts" "$v26" | sort -u); do
    if _node_pnpm_ok "$v"; then
      log_ok "pnpm $NODE_PNPM_MAJOR déjà présent sous Node $v"
    else
      ui_spin "pnpm $NODE_PNPM_MAJOR sous Node $v" \
        _node_nvm exec "$v" npm install -g "pnpm@$NODE_PNPM_MAJOR" || return 1
    fi
  done
  if _node_openspec_ok "$v26"; then
    log_ok "openspec déjà présent sous Node $v26"
  else
    ui_spin "openspec sous Node $v26" _node_nvm exec "$v26" npm install -g "$NODE_OPENSPEC_PKG" || return 1
  fi
}
