#!/usr/bin/env bash
# lib/files.sh — déploiement des fichiers de configuration du dépôt vers ~ (liens
# symboliques, sauvegarde, vérification), clonage idempotent de dépôts git et
# copie idempotente de fichiers système (/etc, avec sudo).
#
# Les fichiers de config vivent dans config/<module>/ (sans point initial) ; un
# module les amène dans ~ par link_config et constate leur état par config_linked.
# Voir openspec/specs/config-files/spec.md et openspec/changes/archive/2026-09-18-shell/design.md (D1, D2) ;
# install_system_file : openspec/changes/navigateur/design.md (D6).
# Dépend de lib/core.sh (DOTFILES_DIR, log_*, run, run_sudo).

# _config_source <rel> : chemin absolu du fichier <rel> du dépôt, ou échec nommé.
_config_source() {
  local src="$DOTFILES_DIR/$1"
  [[ -e $src ]] || { log_error "Fichier de config introuvable dans le dépôt : $src"; return 1; }
  printf '%s\n' "$src"
}

# config_linked <rel> <cible> : vrai si <cible> est un lien vers <dépôt>/<rel>.
# Sans effet de bord : source de vérité pour module_check.
config_linked() {
  local src="$DOTFILES_DIR/$1" target=$2
  [[ -L $target && -e $src ]] || return 1
  [[ $(readlink -f -- "$target") == "$(readlink -f -- "$src")" ]]
}

# link_config <rel> <cible> : crée le lien absolu <cible> → <dépôt>/<rel>.
#   lien déjà bon           → rien (renvoie 0, message « déjà en place »)
#   fichier/dossier ordinaire → sauvegardé en <cible>.bak (ou .bak-<date> si pris)
#   lien vers autre chose   → remplacé sans sauvegarde
#   source absente          → échec, cible intacte
link_config() {
  local rel=$1 target=$2 src backup
  src=$(_config_source "$rel") || return 1
  if config_linked "$rel" "$target"; then
    log_ok "Lien déjà en place : $target → $src"
    return 0
  fi
  if [[ -e $target && ! -L $target ]]; then
    backup="$target.bak"
    [[ -e $backup ]] && backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    mv -- "$target" "$backup" || return 1
    log_warn "Fichier existant sauvegardé : $backup"
  fi
  mkdir -p -- "$(dirname -- "$target")"
  ln -sfn -- "$src" "$target" || return 1
  log_ok "Lien créé : $target → $src"
}

# ensure_git_clone <url> <dossier> [option git clone...] : clone si le dossier
# n'existe pas ; déjà cloné depuis la même URL → rien ; dossier étranger → échec
# nommé, rien n'est touché. Sortie de git au journal (run). Pas de mise à jour
# automatique : c'est une décision explicite du module (ex. `omz update`).
ensure_git_clone() {
  local url=$1 dir=$2 origin
  shift 2
  if [[ -e $dir ]]; then
    # Garde sur .git : sans elle, `git -C` remonterait dans les dossiers parents.
    if [[ ! -d $dir/.git ]] || ! origin=$(git -C "$dir" remote get-url origin 2>/dev/null); then
      log_error "$dir existe mais n'est pas un dépôt git : le déplacer avant de relancer."; return 1
    fi
    if [[ ${origin%.git} == "${url%.git}" ]]; then
      log_ok "Déjà cloné : $dir"
      return 0
    fi
    log_error "$dir est un dépôt étranger (origin : $origin, attendu : $url) : le déplacer avant de relancer."
    return 1
  fi
  run git clone --quiet "$@" -- "$url" "$dir" || return 1
  log_ok "Cloné : $url → $dir"
}

# install_system_file <source> <cible> [mode] : copie <source> vers <cible>, un
# chemin système (/etc/…), avec sudo ; dossiers parents créés, mode 0644 par
# défaut. <source> est relatif au dépôt (config/navigateur/mozilla.pref) ou
# absolu (fichier temporaire généré par le module). Idempotent : rien n'est
# réécrit si le contenu est identique. Copie et non lien : apt et les
# navigateurs exigent des fichiers appartenant à root.
install_system_file() {
  local src=$1 target=$2 mode=${3:-0644}
  [[ $src == /* ]] || { src=$(_config_source "$src") || return 1; }
  [[ -f $src ]] || { log_error "Fichier source introuvable : $src"; return 1; }
  if cmp -s -- "$src" "$target" 2>/dev/null; then
    log_ok "Déjà à jour : $target"
    return 0
  fi
  run_sudo install -m "$mode" -D -- "$src" "$target" || return 1
  log_ok "Écrit : $target"
}
