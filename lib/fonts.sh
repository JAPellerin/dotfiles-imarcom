#!/usr/bin/env bash
# lib/fonts.sh — installation d'une police pour l'utilisateur courant à partir
# d'une archive `.zip` (releases Nerd Fonts, fonderies qui publient un zip).
#
# Installation utilisateur (~/.local/share/fonts), jamais avec sudo : une police
# par utilisateur suffit. L'archive est extraite dans un dossier temporaire et
# n'est recopiée qu'une fois lue en entier, pour ne jamais laisser un dossier de
# police à moitié rempli. Voir openspec/specs/module-contract/spec.md (D5).
# Dépend de lib/core.sh (run, log_*, add_cleanup) et lib/apt.sh (apt_install).
# Chemin surchargeable (tests) : FONTS_DIR.

FONTS_DIR="${FONTS_DIR:-$HOME/.local/share/fonts}"

# font_installed <famille> : vrai si fontconfig connaît la famille. Sans effet de
# bord : utilisable comme critère par module_check.
font_installed() {
  command -v fc-list >/dev/null 2>&1 || return 1
  fc-list : family 2>/dev/null | grep -qiF -- "$1"
}

# install_font <url> <famille> [dossier] : installe la police de l'archive .zip
# <url> sous $FONTS_DIR/<dossier> (par défaut <famille> sans espaces) et
# rafraîchit le cache de polices. Ne fait rien si <famille> est déjà connue.
# Échoue en nommant l'URL si l'archive est injoignable, illisible ou dépourvue de
# fichier de police ; dans ce cas aucun dossier de police n'est laissé derrière.
install_font() {
  local url=${1:-} family=${2:-} dir=${3:-} tmp target created=0
  local files=()
  [[ -n $url && -n $family ]] \
    || { log_error "install_font : arguments manquants (url, famille)"; return 1; }
  [[ -n $dir ]] || dir=${family// /}

  command -v fc-list >/dev/null 2>&1 || apt_install fontconfig || return 1
  if font_installed "$family"; then
    log_ok "Police déjà installée : $family"
    return 0
  fi

  tmp=$(mktemp -d -t "font-$dir.XXXXXX") || return 1
  add_cleanup "rm -rf '$tmp'"
  run curl -fsSL "$url" -o "$tmp/police.zip" \
    || { log_error "Archive de police introuvable : $url"; return 1; }
  run unzip -q -o "$tmp/police.zip" -d "$tmp/extrait" \
    || { log_error "Archive de police illisible : $url"; return 1; }

  # Les archives Nerd Fonts contiennent aussi licences et README : on ne copie
  # que les fichiers de police, et seulement s'il y en a.
  mapfile -t files < <(find "$tmp/extrait" -type f \( -iname '*.ttf' -o -iname '*.otf' \))
  if (( ${#files[@]} == 0 )); then
    log_error "Aucun fichier de police (.ttf/.otf) dans l'archive : $url"
    return 1
  fi
  target="$FONTS_DIR/$dir"
  [[ -d $target ]] || created=1
  mkdir -p -- "$target" || return 1
  cp -f -- "${files[@]}" "$target/" || return 1
  run fc-cache -f "$FONTS_DIR" || return 1

  if ! font_installed "$family"; then
    (( created == 1 )) && rm -rf -- "$target"
    log_error "Police copiée, mais fontconfig ne connaît pas la famille « $family » : vérifier son nom exact (fc-list : family)."
    return 1
  fi
  log_ok "Police installée : $family (${#files[@]} fichier(s) dans $target)"
}
