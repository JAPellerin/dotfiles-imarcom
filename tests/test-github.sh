#!/usr/bin/env bash
# tests/test-github.sh — lib/github.sh sur des réponses JSON fabriquées, servies
# en file:// par GITHUB_API_URL (curl ignore la chaîne de requête `?per_page=` sur
# un fichier) : hors ligne, aucun appel à api.github.com.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/github.sh
source "$DOTFILES_DIR/lib/github.sh"

API="$TEST_TMP/api"
GITHUB_API_URL="file://$API"
DL=https://github.com/editeur

# release <tag> <draft> <prerelease> <fichier...> : un objet release de l'API.
release() {
  local tag=$1 draft=$2 pre=$3 name assets=() IFS=,
  shift 3
  for name in "$@"; do
    assets+=("{\"name\":\"$name\",\"browser_download_url\":\"$DL/$tag/$name\"}")
  done
  printf '{"tag_name":"%s","draft":%s,"prerelease":%s,"assets":[%s]}' "$tag" "$draft" "$pre" "${assets[*]}"
}

# serve <propriétaire/dépôt> <release...> : écrit la liste servie pour ce dépôt.
serve() {
  local repo=$1 IFS=,
  shift
  mkdir -p "$API/repos/$repo"
  printf '[%s]\n' "$*" >"$API/repos/$repo/releases"
}

# call <dépôt> <motif> : stdout dans OUT, stderr dans ERR, code dans RC.
call() {
  RC=0
  OUT=$(github_release_asset_url "$1" "$2" 2>"$TEST_TMP/err") || RC=$?
  ERR=$(<"$TEST_TMP/err")
}

DEB='_amd64\.deb$'

printf '%s\n' "== Dernière release complète =="
serve e/complet \
  "$(release v2 false false app_2_amd64.deb app_2_arm64.deb App-2.AppImage)" \
  "$(release v1 false false app_1_amd64.deb)"
call e/complet "$DEB"
assert_eq "code 0" 0 "$RC"
assert_eq "stdout = l'URL seule, celle de la dernière release" "$DL/v2/app_2_amd64.deb" "$OUT"

printf '%s\n' "== Dernière release sans le fichier (forme d'Obsidian) =="
serve e/obsidian \
  "$(release v1.13.8 false false Obsidian-1.13.8.apk)" \
  "$(release v1.13.7 false false obsidian_1.13.7_amd64.deb Obsidian-1.13.7.AppImage)"
call e/obsidian "$DEB"
assert_eq "URL de la release précédente" "$DL/v1.13.7/obsidian_1.13.7_amd64.deb" "$OUT"

printf '%s\n' "== Préversion et brouillon plus récents ignorés =="
serve e/pre \
  "$(release v4-beta false true app_4_amd64.deb)" \
  "$(release v3 true false app_3_amd64.deb)" \
  "$(release v2 false false app_2_amd64.deb)"
call e/pre "$DEB"
assert_eq "URL de la dernière release publiée" "$DL/v2/app_2_amd64.deb" "$OUT"

printf '%s\n' "== Aucun fichier correspondant =="
serve e/vide \
  "$(release v2 false false app-2.rpm)" \
  "$(release v1 false true app_1_amd64.deb)"
call e/vide "$DEB"
assert_eq "code 1" 1 "$RC"
assert_eq "stdout vide" "" "$OUT"
assert_contains "le message nomme le dépôt" "$ERR" "e/vide"
assert_contains "le message nomme le motif" "$ERR" "$DEB"

printf '%s\n' "== Réponse absente (curl en échec) =="
call e/inconnu "$DEB"
assert_eq "code 1" 1 "$RC"
assert_eq "stdout vide" "" "$OUT"
assert_contains "le message nomme le dépôt" "$ERR" "e/inconnu"

printf '%s\n' "== JSON invalide =="
mkdir -p "$API/repos/e/casse"
printf '<html>limite de débit</html>\n' >"$API/repos/e/casse/releases"
call e/casse "$DEB"
assert_eq "code 1" 1 "$RC"
assert_eq "stdout vide" "" "$OUT"
assert_contains "le message nomme le dépôt" "$ERR" "e/casse"

printf '%s\n' "== Arguments manquants =="
call e/complet ""
assert_eq "motif absent → code 1" 1 "$RC"
assert_eq "stdout vide" "" "$OUT"

test_done
