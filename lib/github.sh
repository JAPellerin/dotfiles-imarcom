#!/usr/bin/env bash
# lib/github.sh — fichiers publiés dans les releases GitHub d'un éditeur, pour
# les logiciels distribués en `.deb` hors dépôt apt (Obsidian, Rocket.Chat).
#
# Référence : API REST de GitHub, « List releases »
# (https://docs.github.com/en/rest/releases/releases#list-releases) — sans jeton,
# 60 requêtes par heure et par adresse ; un appel par module et par installation,
# jamais dans module_check. Voir openspec/changes/socle-github/design.md.
# Dépend de lib/core.sh (log_*) et de jq (module base).
# URL de l'API surchargeable (tests, réponses servies en file://) : GITHUB_API_URL.

GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

# github_release_asset_url <propriétaire/dépôt> <motif> : imprime l'URL de
# téléchargement du premier fichier dont le nom correspond au <motif> (expression
# régulière de jq, syntaxe Oniguruma proche de PCRE, ancrée par l'appelant :
# '_amd64\.deb$') dans la plus récente des releases publiées qui en contient un.
# Brouillons et préversions écartés.
# `/releases/latest` ne suffit pas : la dernière release d'Obsidian (v1.13.8) ne
# contient qu'un `.apk`, le `.deb` est dans la précédente (relevé du 23 sept 2026).
# Stdout ne porte que l'URL : url=$(github_release_asset_url …) || return 1.
github_release_asset_url() {
  local repo=${1:-} pattern=${2:-} json url
  [[ -n $repo && -n $pattern ]] \
    || { log_error "github_release_asset_url : arguments manquants (dépôt, motif)"; return 1; }
  # Motif vérifié avant l'appel réseau : une expression invalide ferait échouer
  # jq plus bas, et l'erreur passerait pour une réponse illisible de l'API.
  jq -n --arg re "$pattern" '"" | test($re)' >/dev/null 2>&1 \
    || { log_error "github_release_asset_url : motif invalide « $pattern » (expression régulière de jq)"; return 1; }
  # Réponse dans une variable, pas de tube curl | jq : un échec de curl (réseau,
  # limite de débit, dépôt inconnu) doit se distinguer d'une liste sans fichier.
  # Pas de fichier temporaire : le helper s'appelle dans un `$(…)`, où
  # add_cleanup se perd (lib/core.sh). Hors `run` : la sortie est le document
  # JSON lui-même. Avec -sS, curl n'écrit sur stderr qu'en cas d'échec (les
  # avertissements de --retry sont tus) : 2>&1 ne mêle rien au JSON d'un succès,
  # et la variable porte la cause d'un échec (403 de la limite de débit, 404…).
  json=$(curl -fsSL --retry 2 "$GITHUB_API_URL/repos/$repo/releases?per_page=20" 2>&1) \
    || { log_error "API GitHub injoignable ou en erreur pour $repo (motif « $pattern ») : $json"; return 1; }
  url=$(jq -r --arg re "$pattern" \
    '[.[] | select((.draft or .prerelease) | not) | .assets[] | select(.name | test($re)) | .browser_download_url][0] // empty' \
    <<<"$json" 2>/dev/null) \
    || { log_error "Réponse illisible de l'API GitHub pour $repo (motif « $pattern »)"; return 1; }
  [[ -n $url ]] \
    || { log_error "Aucune release de $repo ne contient de fichier correspondant à « $pattern »"; return 1; }
  printf '%s\n' "$url"
}
