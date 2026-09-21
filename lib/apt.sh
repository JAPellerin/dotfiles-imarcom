#!/usr/bin/env bash
# lib/apt.sh — helpers apt : paquets manquants seulement (ou version épinglée,
# retrait), `apt update` au plus une fois par exécution, dépôts tiers au format
# deb822 avec clé dans /etc/apt/keyrings/.
#
# Références : sources.list(5) (format deb822 `.sources`, champ Signed-By) et la
# pratique d'Ubuntu 26.04 (/etc/apt/sources.list.d/ubuntu.sources). Voir D10.
# Dépend de lib/core.sh (run, run_sudo, log_*) et lib/ui.sh (ui_spin).
# Toute écriture système passe par run_sudo ; les chemins sont surchargeables
# (tests) : APT_KEYRINGS_DIR, APT_SOURCES_DIR.

APT_KEYRINGS_DIR="${APT_KEYRINGS_DIR:-/etc/apt/keyrings}"
APT_SOURCES_DIR="${APT_SOURCES_DIR:-/etc/apt/sources.list.d}"
_APT_UPDATED=0

# pkg_installed <paquet> : vrai si le paquet est installé (état dpkg « install ok installed »).
pkg_installed() {
  [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == "install ok installed" ]]
}

# apt_mark_stale : force un `apt update` au prochain appel d'apt_update_once
# (après l'ajout d'un dépôt, par exemple).
apt_mark_stale() { _APT_UPDATED=0; }

# apt_update_once : `apt-get update`, une seule fois par exécution du runner
# (sauf apt_mark_stale entre-temps).
apt_update_once() {
  (( _APT_UPDATED == 1 )) && return 0
  ui_spin "Mise à jour des index apt" run_sudo apt-get update -q || return $?
  _APT_UPDATED=1
}

# apt_install <paquet...> : installe uniquement les paquets manquants, sans
# question (DEBIAN_FRONTEND=noninteractive). Renvoie 0 si rien à faire.
apt_install() {
  local pkg missing=()
  for pkg in "$@"; do
    pkg_installed "$pkg" || missing+=("$pkg")
  done
  if (( ${#missing[@]} == 0 )); then
    log_ok "Paquets déjà installés : $*"
    return 0
  fi
  apt_update_once || return $?
  ui_spin "Installation apt : ${missing[*]}" \
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${missing[@]}"
}

# apt_install_pinned <paquet...> : `apt-get install` inconditionnel — installe le
# paquet ou le bascule vers la version que la politique apt sélectionne
# (épinglage : le firefox de Mozilla par-dessus le paquet de transition d'Ubuntu,
# voir openspec/changes/navigateur/design.md D3), même si un paquet du même nom
# est déjà installé. `--allow-downgrades` : sans lui, `-y` refuse un déclassement
# (constaté en VM le 21 sept 2026 : « 1:1snap1 » → « 154.0 » est un déclassement
# d'époque). Dans le cas courant, apt_install suffit.
apt_install_pinned() {
  apt_update_once || return $?
  ui_spin "Installation apt (version épinglée) : $*" \
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -q --allow-downgrades "$@"
}

# apt_remove <paquet...> : retire uniquement les paquets présents, sans question.
# Renvoie 0 si rien à faire.
apt_remove() {
  local pkg present=()
  for pkg in "$@"; do
    pkg_installed "$pkg" && present+=("$pkg")
  done
  if (( ${#present[@]} == 0 )); then
    log_ok "Paquets déjà absents : $*"
    return 0
  fi
  ui_spin "Retrait apt : ${present[*]}" \
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get remove -y -q "${present[@]}"
}

# apt_add_repo <nom> <url-clé> <url-dépôt> <suite> <composants> [architectures]
# Écrit la clé dans $APT_KEYRINGS_DIR/<nom>.asc (armurée) ou .gpg (binaire) et le
# fichier $APT_SOURCES_DIR/<nom>.sources en deb822. Idempotent : ne réécrit un
# fichier que si son contenu change, et ne relance `apt update` que dans ce cas.
#   <suite> vide ou « auto » → nom de code de la distribution (/etc/os-release)
#   [architectures] omis   → `dpkg --print-architecture`
# Exemple (Docker) : apt_add_repo docker https://download.docker.com/linux/ubuntu/gpg \
#                      https://download.docker.com/linux/ubuntu auto stable
apt_add_repo() {
  local name=${1:-} key_url=${2:-} repo_url=${3:-} suite=${4:-auto} components=${5:-} archs=${6:-}
  local tmp_key key_file sources_file changed=0
  [[ -n $name && -n $key_url && -n $repo_url && -n $components ]] \
    || { log_error "apt_add_repo : arguments manquants (nom, url-clé, url-dépôt, suite, composants)"; return 1; }

  if [[ -z $suite || $suite == auto ]]; then
    suite=$(. /etc/os-release && printf '%s' "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
  fi
  [[ -n $archs ]] || archs=$(dpkg --print-architecture)

  # 1. Clé : téléchargée dans un fichier temporaire, extension selon son contenu.
  tmp_key=$(mktemp -t "apt-key-$name.XXXXXX")
  add_cleanup "rm -f '$tmp_key'"
  run curl -fsSL "$key_url" -o "$tmp_key" || { log_error "Clé introuvable : $key_url"; return 1; }
  if grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$tmp_key"; then
    key_file="$APT_KEYRINGS_DIR/$name.asc"
  else
    key_file="$APT_KEYRINGS_DIR/$name.gpg"
  fi
  if ! cmp -s "$tmp_key" "$key_file" 2>/dev/null; then
    run_sudo install -m 0755 -d "$APT_KEYRINGS_DIR" || return 1
    run_sudo install -m 0644 "$tmp_key" "$key_file" || return 1
    changed=1
  fi

  # 2. Fichier .sources deb822, comparé au contenu existant avant écriture.
  sources_file="$APT_SOURCES_DIR/$name.sources"
  local tmp_sources
  tmp_sources=$(mktemp -t "apt-sources-$name.XXXXXX")
  add_cleanup "rm -f '$tmp_sources'"
  cat >"$tmp_sources" <<SRC
Types: deb
URIs: $repo_url
Suites: $suite
Components: $components
Architectures: $archs
Signed-By: $key_file
SRC
  if ! cmp -s "$tmp_sources" "$sources_file" 2>/dev/null; then
    run_sudo install -m 0644 "$tmp_sources" "$sources_file" || return 1
    changed=1
  fi

  if (( changed == 1 )); then
    log_info "Dépôt apt « $name » écrit dans $sources_file"
    apt_mark_stale
    apt_update_once
  else
    log_ok "Dépôt apt « $name » déjà en place"
  fi
}
