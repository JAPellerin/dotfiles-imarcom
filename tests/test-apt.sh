#!/usr/bin/env bash
# tests/test-apt.sh — lib/apt.sh hors ligne et sans sudo : run_sudo est doublé
# (les commandes apt-get sont seulement comptées, les autres exécutées sans sudo)
# et les dossiers système pointent vers le dossier temporaire du test.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
APT_KEYRINGS_DIR="$TEST_TMP/keyrings"
APT_SOURCES_DIR="$TEST_TMP/sources.list.d"
mkdir -p "$APT_SOURCES_DIR"   # existe toujours sur un vrai système
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"

CALLS="$TEST_TMP/calls"
: >"$CALLS"
# Doublure : journalise l'appel ; apt-get n'est pas exécuté, le reste tourne en utilisateur.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  [[ $1 == env ]] && { shift; shift; }
  [[ $1 == apt-get ]] && return 0
  run "$@"
}
count_calls() { grep -c -- "$1" "$CALLS" || true; }

printf '%s\n' "== pkg_installed =="
assert_ok   "bash est installé" pkg_installed bash
assert_fail "un paquet fictif n'est pas installé" pkg_installed paquet-fictif-dotfiles

printf '%s\n' "== apt_update_once =="
apt_update_once 2>/dev/null; apt_update_once 2>/dev/null
assert_eq "apt-get update lancé une seule fois pour deux appels" 1 "$(count_calls 'apt-get update')"
apt_mark_stale; apt_update_once 2>/dev/null
assert_eq "apt_mark_stale force un nouvel apt-get update" 2 "$(count_calls 'apt-get update')"

printf '%s\n' "== apt_install =="
: >"$CALLS"; _APT_UPDATED=1
apt_install bash coreutils 2>/dev/null
assert_eq "aucun apt-get install si tout est déjà installé" 0 "$(count_calls 'apt-get install')"
apt_install bash paquet-fictif-dotfiles autre-fictif 2>/dev/null
assert_eq "apt-get install lancé pour les manquants" 1 "$(count_calls 'apt-get install')"
assert_contains "seuls les paquets manquants sont passés" "$(cat "$CALLS")" "apt-get install -y -q paquet-fictif-dotfiles autre-fictif"
assert_not_contains "les paquets présents ne sont pas réinstallés" "$(grep 'apt-get install' "$CALLS")" "bash"
assert_contains "installation non interactive" "$(cat "$CALLS")" "DEBIAN_FRONTEND=noninteractive"

printf '%s\n' "== apt_install_pinned =="
: >"$CALLS"; _APT_UPDATED=1
apt_install_pinned bash 2>/dev/null
assert_eq "apt-get install lancé même si le paquet est installé" 1 "$(count_calls 'apt-get install -y -q --allow-downgrades bash')"
assert_contains "installation non interactive" "$(cat "$CALLS")" "DEBIAN_FRONTEND=noninteractive"
: >"$CALLS"; _APT_UPDATED=0
apt_install_pinned bash 2>/dev/null
assert_eq "apt-get update d'abord si les index sont périmés" 1 "$(count_calls 'apt-get update')"

printf '%s\n' "== apt_remove =="
: >"$CALLS"
assert_ok "paquet absent : réussit" apt_remove paquet-fictif-dotfiles
assert_eq "paquet absent : aucun apt-get remove" 0 "$(count_calls 'apt-get remove')"
apt_remove bash paquet-fictif-dotfiles 2>/dev/null
assert_eq "apt-get remove lancé pour les présents" 1 "$(count_calls 'apt-get remove')"
assert_contains "seuls les paquets présents sont retirés" "$(cat "$CALLS")" "apt-get remove -y -q bash"
assert_not_contains "les absents ne sont pas passés" "$(grep 'apt-get remove' "$CALLS")" "paquet-fictif"

printf '%s\n' "== apt_add_repo =="
: >"$CALLS"; _APT_UPDATED=1
KEY="$TEST_TMP/cle.asc"
printf -- '-----BEGIN PGP PUBLIC KEY BLOCK-----\nfausse-cle\n-----END PGP PUBLIC KEY BLOCK-----\n' >"$KEY"
assert_ok "premier ajout du dépôt" apt_add_repo test-repo "file://$KEY" https://exemple.test/apt stable main amd64
assert_file "clé écrite dans le keyring (.asc car armurée)" "$APT_KEYRINGS_DIR/test-repo.asc"
assert_file "fichier .sources créé" "$APT_SOURCES_DIR/test-repo.sources"
expected="Types: deb
URIs: https://exemple.test/apt
Suites: stable
Components: main
Architectures: amd64
Signed-By: $APT_KEYRINGS_DIR/test-repo.asc"
assert_eq "contenu deb822 conforme" "$expected" "$(cat "$APT_SOURCES_DIR/test-repo.sources")"
assert_eq "apt-get update lancé après l'ajout" 1 "$(count_calls 'apt-get update')"
installs_before=$(count_calls 'install -m 0644')
assert_ok "second ajout identique" apt_add_repo test-repo "file://$KEY" https://exemple.test/apt stable main amd64
assert_eq "second appel : aucune réécriture des fichiers" "$installs_before" "$(count_calls 'install -m 0644')"
assert_eq "second appel : pas de nouvel apt-get update" 1 "$(count_calls 'apt-get update')"
assert_ok "changement de composants" apt_add_repo test-repo "file://$KEY" https://exemple.test/apt stable "main contrib" amd64
assert_contains "le .sources est réécrit quand le contenu change" "$(cat "$APT_SOURCES_DIR/test-repo.sources")" "Components: main contrib"
assert_eq "apt-get update relancé après le changement" 2 "$(count_calls 'apt-get update')"

printf '%s\n' "== apt_add_repo : valeurs par défaut =="
codename=$(sed -n 's/^UBUNTU_CODENAME=//p' /etc/os-release)
printf 'cle-binaire' >"$TEST_TMP/cle.gpg"
assert_ok "suite auto et architecture par défaut" apt_add_repo defauts "file://$TEST_TMP/cle.gpg" https://exemple.test/apt auto main
assert_file "clé binaire → .gpg" "$APT_KEYRINGS_DIR/defauts.gpg"
assert_contains "suite = nom de code de la distribution" "$(cat "$APT_SOURCES_DIR/defauts.sources")" "Suites: $codename"
assert_contains "architecture = dpkg --print-architecture" "$(cat "$APT_SOURCES_DIR/defauts.sources")" "Architectures: $(dpkg --print-architecture)"
assert_fail "clé introuvable → échec" apt_add_repo absent "file://$TEST_TMP/nexiste-pas" https://exemple.test/apt stable main
assert_fail "arguments manquants → échec" apt_add_repo seulement-nom

test_done
