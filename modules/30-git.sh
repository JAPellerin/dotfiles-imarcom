#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/30-git.sh — git prêt à l'emploi : ~/.gitconfig versionné (identité,
# delta), git-delta, gh depuis le dépôt apt officiel, clé SSH fournie par
# 1Password selon l'environnement, hôtes connus GitHub, connexion gh.
#
# Procédures officielles suivies :
#   gh     : https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian-ubuntu-linux-raspberry-pi-os-apt
#            (même dépôt et même clé ; format deb822 + clé dans /etc/apt/keyrings/, design D10 du socle)
#   delta  : https://github.com/dandavison/delta#get-started
#   op     : https://developer.1password.com/docs/cli/reference/commands/read (ssh-format=openssh)
#   hôtes  : https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
# Voir openspec/specs/module-git/spec.md et openspec/changes/archive/2026-09-21-git/design.md.
MODULE_NAME="git"
MODULE_DESC="git : identité et delta (gitconfig versionné) ; gh ; clé SSH depuis 1Password ; hôtes GitHub connus"
MODULE_GROUP="dev"
MODULE_DEPS="base 1password"

# Convention des secrets (D1) : op://Private/<Item>/<champ>, champs nommés comme dans 1Password.
GIT_SSH_KEY_REF="op://Private/GitHub SSH Key/private key?ssh-format=openssh"
GIT_SSH_PUB_REF="op://Private/GitHub SSH Key/public key"
GIT_SSH_DIR="$HOME/.ssh"
GIT_SSH_KEY="$GIT_SSH_DIR/id_ed25519"
GIT_KNOWN_HOSTS="$GIT_SSH_DIR/known_hosts"
GIT_GH_KEY_URL="https://cli.github.com/packages/githubcli-archive-keyring.gpg"
GIT_GH_REPO_URL="https://cli.github.com/packages"
GIT_GITHUB_META_URL="https://api.github.com/meta"

# Déjà fait = delta et gh installés, ~/.gitconfig lié, github.com dans
# known_hosts, clé privée présente quand l'agent 1Password n'est pas là, jeton gh
# enregistré (lecture locale, sans réseau : module_check tourne à chaque menu).
module_check() {
  pkg_installed git-delta && pkg_installed gh || return 1
  config_linked config/git/gitconfig "$HOME/.gitconfig" || return 1
  ssh-keygen -F github.com -f "$GIT_KNOWN_HOSTS" >/dev/null 2>&1 || return 1
  _git_agent_available || [[ -f $GIT_SSH_KEY ]] || return 1
  gh auth token >/dev/null 2>&1
}

# L'agent SSH de l'application 1Password sert la clé : aucun fichier à écrire.
_git_agent_available() { pkg_installed 1password; }

module_install() {
  apt_install git-delta || return 1
  apt_add_repo github-cli "$GIT_GH_KEY_URL" "$GIT_GH_REPO_URL" stable main || return 1
  apt_install gh || return 1
  log_ok "delta $(delta --version 2>/dev/null | awk '{print $2}') ; gh $(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
}

module_configure() {
  # Le lien après delta : core.pager=delta casserait git diff si delta manquait.
  link_config config/git/gitconfig "$HOME/.gitconfig" || return 1
  _git_known_hosts || return 1
  _git_ssh_key || return 1
  _git_gh_login
}

# ~/.ssh en 0700 (le seul niveau créé : ~ existe toujours).
_git_ssh_dir() { [[ -d $GIT_SSH_DIR ]] || { mkdir -- "$GIT_SSH_DIR" && chmod 0700 "$GIT_SSH_DIR"; }; }

# Clés SSH publiques de github.com depuis la source officielle, sans doublon.
_git_known_hosts() {
  local keys line added=0
  keys=$({ curl -fsSL "$GIT_GITHUB_META_URL" | jq -r '.ssh_keys[]'; } 2>>"$LOG_FILE") || {
    log_error "Impossible de lire les clés SSH de GitHub ($GIT_GITHUB_META_URL) : voir le journal."; return 1; }
  [[ -n $keys ]] || { log_error "Aucune clé SSH dans la réponse de $GIT_GITHUB_META_URL"; return 1; }
  _git_ssh_dir
  [[ -f $GIT_KNOWN_HOSTS ]] || { : >"$GIT_KNOWN_HOSTS"; chmod 0600 "$GIT_KNOWN_HOSTS"; }
  while IFS= read -r line; do
    ensure_line "$GIT_KNOWN_HOSTS" "github.com $line" && added=$((added + 1))
  done <<<"$keys"
  ssh-keygen -F github.com -f "$GIT_KNOWN_HOSTS" >/dev/null 2>&1 \
    || { log_error "github.com absent de $GIT_KNOWN_HOSTS après ajout."; return 1; }
  if (( added )); then log_ok "Hôte github.com ajouté à $GIT_KNOWN_HOSTS ($added clé(s))."
  else log_ok "Hôte github.com déjà dans $GIT_KNOWN_HOSTS."; fi
}

# Clé SSH (D2) : agent 1Password avec l'app ; sinon fichiers écrits depuis
# 1Password, seulement s'ils manquent. La valeur ne passe que par une variable.
_git_ssh_key() {
  local key pub
  if _git_agent_available; then
    log_info "Clé SSH servie par l'agent 1Password (SSH_AUTH_SOCK) : aucun fichier de clé écrit."
    return 0
  fi
  _git_ssh_dir
  if [[ -f $GIT_SSH_KEY ]]; then
    log_ok "Clé privée déjà présente : $GIT_SSH_KEY (laissée intacte)."
  else
    key=$(op_read "$GIT_SSH_KEY_REF") || return 1
    ( umask 077; printf '%s\n' "$key" >"$GIT_SSH_KEY" ) || return 1
    chmod 0600 "$GIT_SSH_KEY"
    log_ok "Clé privée écrite depuis 1Password : $GIT_SSH_KEY"
  fi
  if [[ ! -f $GIT_SSH_KEY.pub ]]; then
    pub=$(op_read "$GIT_SSH_PUB_REF") || return 1
    printf '%s\n' "$pub" >"$GIT_SSH_KEY.pub" || return 1
    chmod 0644 "$GIT_SSH_KEY.pub"
    log_ok "Clé publique écrite : $GIT_SSH_KEY.pub ($(ssh-keygen -l -f "$GIT_SSH_KEY.pub" 2>/dev/null | awk '{print $2}'))"
  fi
}

# Connexion gh (D3) : interactive, par navigateur ; gh garde le jeton lui-même.
_git_gh_login() {
  if gh auth status >/dev/null 2>&1; then
    log_ok "gh déjà connecté ($(gh api user --jq .login 2>/dev/null || echo github.com))."
    return 0
  fi
  log_info "Connexion à GitHub : gh affiche un code à saisir dans le navigateur (ouvert automatiquement, sinon suivre l'URL affichée)."
  if ! gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key; then
    log_error "Connexion gh interrompue : relancer « setup.sh git » pour réessayer."
    return 1
  fi
  gh auth status >/dev/null 2>&1 || { log_error "gh toujours déconnecté après gh auth login."; return 1; }
  log_ok "gh connecté à github.com."
}
