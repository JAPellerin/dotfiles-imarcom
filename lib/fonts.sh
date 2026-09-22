#!/usr/bin/env bash
# lib/fonts.sh — installation d'une police pour l'utilisateur courant à partir
# d'archives `.zip` (releases Nerd Fonts) ou de fichiers `.ttf`/`.otf` publiés
# tels quels (Powerlevel10k publie ainsi les quatre fichiers de MesloLGS NF).
#
# Installation utilisateur (~/.local/share/fonts), jamais avec sudo : une police
# par utilisateur suffit. Tout est reçu dans un dossier temporaire et n'est
# recopié qu'une fois l'ensemble obtenu, pour ne jamais laisser un dossier de
# police à moitié rempli. Voir openspec/specs/module-contract/spec.md (D5).
# Dépend de lib/core.sh (run, log_*, add_cleanup) et lib/apt.sh (apt_install).
# Chemin surchargeable (tests) : FONTS_DIR.

FONTS_DIR="${FONTS_DIR:-$HOME/.local/share/fonts}"

# font_installed <famille> : vrai si fontconfig connaît la famille. Sans effet de
# bord : utilisable comme critère par module_check.
# `fc-list : family` sort une famille par ligne, ses alias séparés par des
# virgules et certains caractères échappés (« Unifont\-JP ») : on découpe sur la
# virgule et on retire les contre-obliques avant de comparer. Comparaison
# **exacte** (`-x`) et non par sous-chaîne : « JetBrainsMono Nerd Font » ne doit
# pas être tenue pour installée par la seule présence de « JetBrainsMono Nerd
# Font Mono ».
# `grep -ixF … >/dev/null` et surtout **pas** `grep -q` : avec -q, grep sort dès
# la première correspondance et tue fc-list par SIGPIPE ; sous `set -o pipefail`
# — que setup.sh active — le pipeline renvoie alors 141 et la police est déclarée
# absente alors qu'elle est là. Constaté en VM le 22 sept 2026, sur 234 familles.
font_installed() {
  command -v fc-list >/dev/null 2>&1 || return 1
  # shellcheck disable=SC1003  # '\\' : contre-oblique littérale pour tr, pas une apostrophe échappée
  fc-list : family 2>/dev/null | tr ',' '\n' | tr -d '\\' | grep -ixF -- "$1" >/dev/null
}

# _font_basename <url> : nom de fichier lisible tiré de l'URL, pourcents décodés
# (« MesloLGS%20NF%20Regular.ttf » → « MesloLGS NF Regular.ttf »). Le nom n'a
# aucune portée fonctionnelle — fontconfig lit la famille dans la table de noms
# du fichier, pas dans son nom — mais un dossier de polices se relit.
_font_basename() {
  local name=${1##*/}
  name=${name%%\?*}
  case $name in
    # Décodage seulement en présence d'un vrai %XX, pour ne pas maltraiter un
    # nom qui contiendrait un pourcent isolé.
    *%[0-9A-Fa-f][0-9A-Fa-f]*) printf '%b' "${name//%/\\x}" ;;
    *) printf '%s' "$name" ;;
  esac
}

# install_font <famille> <dossier> <url...> : installe la police <famille> sous
# $FONTS_DIR/<dossier> à partir d'une ou plusieurs URL, puis rafraîchit le cache.
# Chaque URL est traitée selon son extension : `.zip` extraite (tous ses fichiers
# de police sont pris), `.ttf` ou `.otf` installée telle quelle. Ne fait rien si
# <famille> est déjà connue de fontconfig. Échoue en nommant l'URL fautive si un
# téléchargement ou une extraction échoue, ou si une archive ne contient aucune
# police ; dans ce cas aucun dossier de police n'est laissé derrière.
install_font() {
  # Contrôle avant tout `shift` : sans lui, un appel à un seul argument ferait
  # passer la famille pour une URL.
  if (( $# < 3 )) || [[ -z ${1:-} || -z ${2:-} ]]; then
    log_error "install_font : arguments manquants (famille, dossier, url...)"
    return 1
  fi
  local family=$1 dir=$2
  shift 2
  local tmp target url name recu n=0 f
  local files=()

  command -v fc-list >/dev/null 2>&1 || apt_install fontconfig || return 1
  if font_installed "$family"; then
    log_ok "Police déjà installée : $family"
    return 0
  fi

  tmp=$(mktemp -d -t "font-$dir.XXXXXX") || return 1
  add_cleanup "rm -rf '$tmp'"
  recu="$tmp/recu"
  mkdir -p -- "$recu" || return 1

  for url in "$@"; do
    n=$(( n + 1 ))
    case ${url##*/} in
      *.zip|*.ZIP)
        # Chaque archive dans son propre sous-dossier : c'est ce qui permet de
        # nommer l'archive fautive quand elle ne contient aucune police.
        run curl -fsSL "$url" -o "$tmp/archive-$n.zip" \
          || { log_error "Archive de police introuvable : $url"; return 1; }
        run unzip -q -o "$tmp/archive-$n.zip" -d "$recu/z$n" \
          || { log_error "Archive de police illisible : $url"; return 1; }
        if [[ -z $(find "$recu/z$n" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print -quit) ]]; then
          log_error "Aucun fichier de police (.ttf/.otf) dans l'archive : $url"
          return 1
        fi
        ;;
      *.ttf|*.TTF|*.otf|*.OTF)
        name=$(_font_basename "$url")
        run curl -fsSL "$url" -o "$recu/$name" \
          || { log_error "Fichier de police introuvable : $url"; return 1; }
        ;;
      *)
        log_error "URL de police non reconnue (.zip, .ttf ou .otf attendu) : $url"
        return 1
        ;;
    esac
  done

  # Les archives Nerd Fonts contiennent aussi licences et README : on ne copie
  # que les fichiers de police.
  mapfile -t files < <(find "$recu" -type f \( -iname '*.ttf' -o -iname '*.otf' \))
  if (( ${#files[@]} == 0 )); then
    log_error "Aucun fichier de police obtenu pour « $family »."
    return 1
  fi
  target="$FONTS_DIR/$dir"
  mkdir -p -- "$target" || return 1
  cp -f -- "${files[@]}" "$target/" || return 1
  run fc-cache -f "$FONTS_DIR" || return 1

  if ! font_installed "$family"; then
    # Ne rien laisser d'incomplet derrière : on retire les fichiers que l'on
    # vient de copier, puis le dossier s'il est devenu vide (s'il contenait déjà
    # une autre police, elle reste en place).
    for f in "${files[@]}"; do rm -f -- "$target/${f##*/}"; done
    rmdir -- "$target" 2>/dev/null || true
    log_error "Police copiée, mais fontconfig ne connaît pas la famille « $family » : vérifier son nom exact (fc-list : family)."
    return 1
  fi
  log_ok "Police installée : $family (${#files[@]} fichier(s) dans $target)"
}
