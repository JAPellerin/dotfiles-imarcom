#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/80-projets.sh — dépôts de travail de l'utilisateur, clonés d'après un
# arbre gardé dans 1Password, et ce que leurs projets demandent au poste sans
# pouvoir le poser eux-mêmes : autorité mkcert, domaines locaux dans /etc/hosts,
# bitbucket.org parmi les hôtes connus, accès SSH à l'hôte legacy.
#
# Suit la doc officielle :
#   https://support.atlassian.com/bitbucket-cloud/docs/configure-ssh-and-two-step-verification/
#   https://github.com/FiloSottile/mkcert#installation            (mkcert -install)
#   https://developer.1password.com/docs/ssh/agent/config/         (coffres servis par l'agent)
# Aucune donnée propre aux projets ici (dépôt public) : arbre, domaines et bloc
# SSH vivent dans 1Password (D1). Le module ne touche jamais un clone existant ;
# relevé et mise à jour passent par `setup.sh --snapshot-projets` et
# `--pull-projets` (projets_snapshot, projets_pull, D8 à D10). `make setup`
# reste au projet : étape manuelle pour chaque dépôt fraîchement cloné (D3).
# Voir openspec/changes/projets/specs/module-projets/spec.md et openspec/changes/projets/design.md.
MODULE_NAME="projets"
MODULE_DESC="dépôts de travail depuis 1Password ; mkcert ; domaines locaux ; accès SSH legacy"
MODULE_GROUP="projets"
MODULE_DEPS="base 1password git"

PROJETS_ROOT_REL="projets"
PROJETS_ROOT="$HOME/$PROJETS_ROOT_REL"
# Élément des projets (D1) : arbre en notesPlain (chemin<TAB>url), domaines en hosts.
PROJETS_OP_VAULT="Imarcom"
PROJETS_OP_TITLE="Projets"
PROJETS_OP_ITEM="op://$PROJETS_OP_VAULT/$PROJETS_OP_TITLE"
PROJETS_TREE_REF="$PROJETS_OP_ITEM/notesPlain"
PROJETS_HOSTS_REF="$PROJETS_OP_ITEM/hosts"
# URL d'un dépôt git distant (D2) ; surchargeable (tests : file://).
PROJETS_URL_RE="${PROJETS_URL_RE:-^(git@[A-Za-z0-9.-]+:[A-Za-z0-9._/~-]+|(ssh|https)://[A-Za-z0-9.@:_/~-]+)$}"
PROJETS_HOST_RE='^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$'
PROJETS_BITBUCKET_KEYS_URL="https://bitbucket.org/site/ssh"
PROJETS_SSH_DIR="$HOME/.ssh"
PROJETS_KNOWN_HOSTS="$PROJETS_SSH_DIR/known_hosts"
# Fichiers système ; surchargeables (tests).
PROJETS_HOSTS_FILE="${PROJETS_HOSTS_FILE:-/etc/hosts}"
PROJETS_CA_DIR="${PROJETS_CA_DIR:-/usr/local/share/ca-certificates}"
# Accès legacy (D7) : coffre Private, que l'agent de 1Password sert sans agent.toml.
PROJETS_LEGACY_ITEM="op://Private/Legacy SSH"
PROJETS_LEGACY_KEY="$PROJETS_SSH_DIR/id_ed25519_legacy"
PROJETS_SSH_CONFIG="$PROJETS_SSH_DIR/config"
PROJETS_SSH_CONF_DIR="$PROJETS_SSH_DIR/config.d"
PROJETS_SSH_CONF="$PROJETS_SSH_CONF_DIR/projets.conf"
PROJETS_SSH_INCLUDE="Include config.d/*.conf"
PROJETS_SNAPSHOT_MANUAL="Relever les projets sur le poste de référence (setup.sh --snapshot-projets), ouvrir une session 1Password, puis relancer « setup.sh projets »."
PROJETS_LEGACY_MANUAL="Importer la clé SSH legacy dans 1Password (coffre Private, élément « Legacy SSH », bloc Host en note), puis relancer « setup.sh projets »."

# --- Environnement ------------------------------------------------------------------------

# _projets_env : SSH par l'agent de 1Password quand il est prêt (le fragment du
# module 1password n'agit que dans un nouveau terminal, D3) ; git sans question.
_projets_env() {
  op_agent_ready && export SSH_AUTH_SOCK="$OP_AGENT_SOCK"
  export GIT_SSH_COMMAND="ssh -o BatchMode=yes" GIT_TERMINAL_PROMPT=0
}

# L'agent SSH de l'application 1Password sert les clés (même critère que `git`).
_projets_agent_available() { pkg_installed 1password; }

# _projets_read <référence> : valeur dans _PROJ_VALUE. Codes : 0 lu, 3 champ ou
# élément absent, 1 autre erreur. Erreurs de op versées au journal.
_PROJ_VALUE=""
_projets_read() {
  local errf err rc=0
  _PROJ_VALUE=""
  errf=$(mktemp -t dotfiles-projets-op.XXXXXX) || return 1
  _PROJ_VALUE=$(op_read "$1" 2>"$errf") || rc=$?
  err=$(<"$errf"); rm -f -- "$errf"
  [[ -n $err ]] && printf '%s\n' "$err" >>"$LOG_FILE"
  (( rc == 0 )) && return 0
  [[ $err == *"does not have a field"* || $err == *"isn't an item"* ]] && return 3
  return 1
}

# --- Arbre des dépôts (D1, D2) -----------------------------------------------------------

# _projets_valid_path <chemin> : relatif, sous projets/, sans segment vide, . ni ..
_projets_valid_path() {
  local p=$1
  [[ $p == "$PROJETS_ROOT_REL"/* && $p =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  [[ /$p/ != *//* && /$p/ != */./* && /$p/ != */../* ]]
}

# _projets_parse_tree <texte> : lignes valides dans TREE_PATHS / TREE_URLS ; les
# autres sont nommées dans un avertissement, jamais une erreur (spec).
TREE_PATHS=(); TREE_URLS=()
_projets_parse_tree() {
  local line path url
  TREE_PATHS=(); TREE_URLS=()
  while IFS= read -r line; do
    line=${line%$'\r'}
    [[ -z ${line//[[:space:]]/} || $line == \#* ]] && continue
    IFS=$'\t' read -r path url _ <<<"$line"
    path=${path%/}
    if ! _projets_valid_path "$path" || ! [[ $url =~ $PROJETS_URL_RE ]]; then
      log_warn "Projets : ligne de l'arbre refusée (chemin hors de ~/$PROJETS_ROOT_REL ou URL invalide) : $line"
      continue
    fi
    TREE_PATHS+=("$path"); TREE_URLS+=("$url")
  done <<<"$1"
}

# _projets_load_tree : arbre lu dans 1Password. 0 si au moins une ligne valide,
# 2 sinon (sans session, illisible, vide : l'appelant décide).
_projets_load_tree() {
  op_session_active || { log_warn "Projets : aucune session 1Password, arbre des dépôts illisible."; return 2; }
  if ! _projets_read "$PROJETS_TREE_REF"; then
    log_warn "Projets : arbre illisible dans 1Password (« $PROJETS_TREE_REF »)."; return 2
  fi
  _projets_parse_tree "$_PROJ_VALUE"
  (( ${#TREE_PATHS[@]} > 0 )) || { log_warn "Projets : arbre vide dans 1Password (« $PROJETS_TREE_REF »)."; return 2; }
}

# --- Clones (D3) ----------------------------------------------------------------------------

# _projets_clone <chemin> <url> : clone si absent. Codes : 0 déjà là (même
# origine), 10 cloné, 1 échec (nommé par ensure_git_clone ou ici).
_projets_clone() {
  local path=$1 url=$2 dir=$HOME/$1
  if [[ -e $dir ]]; then
    ensure_git_clone "$url" "$dir"
    return
  fi
  mkdir -p -- "$(dirname -- "$dir")" || return 1
  ensure_git_clone "$url" "$dir" || { log_error "Projets : clonage impossible de ~/$path (voir le journal)."; return 1; }
  return 10
}

# _projets_setup_step <chemin> : étape `make setup` pour un dépôt qui en a une.
_projets_setup_step() {
  [[ -f $HOME/$1/Makefile ]] && grep -qE '^setup:' -- "$HOME/$1/Makefile" \
    && manual_step "Préparer le projet : cd ~/$1 && make setup"
  return 0
}

# _projets_clone_all : clone ce qui manque ; tente tout, rend 1 si un échec.
_PROJ_CLONED=()
_projets_clone_all() {
  local i rc failed=0
  _PROJ_CLONED=()
  for i in "${!TREE_PATHS[@]}"; do
    rc=0; _projets_clone "${TREE_PATHS[i]}" "${TREE_URLS[i]}" || rc=$?
    case $rc in
      0) ;;
      10) _PROJ_CLONED+=("${TREE_PATHS[i]}"); _projets_setup_step "${TREE_PATHS[i]}" ;;
      *) failed=1 ;;
    esac
  done
  return "$failed"
}

# --- Hôte Bitbucket (D4) ----------------------------------------------------------------------

_projets_ssh_dir() { [[ -d $PROJETS_SSH_DIR ]] || { mkdir -- "$PROJETS_SSH_DIR" && chmod 0700 "$PROJETS_SSH_DIR"; }; }

_projets_known_hosts() {
  local keys line added=0
  keys=$(curl -fsSL "$PROJETS_BITBUCKET_KEYS_URL" 2>>"$LOG_FILE") || {
    log_error "Impossible de lire les clés SSH de Bitbucket ($PROJETS_BITBUCKET_KEYS_URL) : voir le journal."; return 1; }
  _projets_ssh_dir
  [[ -f $PROJETS_KNOWN_HOSTS ]] || { : >"$PROJETS_KNOWN_HOSTS"; chmod 0600 "$PROJETS_KNOWN_HOSTS"; }
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    [[ $line == "bitbucket.org "* ]] || { log_error "Réponse inattendue de $PROJETS_BITBUCKET_KEYS_URL : voir le journal."; printf '%s\n' "$keys" >>"$LOG_FILE"; return 1; }
    ensure_line "$PROJETS_KNOWN_HOSTS" "$line" && added=$((added + 1))
  done <<<"$keys"
  ssh-keygen -F bitbucket.org -f "$PROJETS_KNOWN_HOSTS" >/dev/null 2>&1 \
    || { log_error "bitbucket.org absent de $PROJETS_KNOWN_HOSTS après ajout."; return 1; }
  if (( added )); then log_ok "Hôte bitbucket.org ajouté à $PROJETS_KNOWN_HOSTS ($added clé(s))."
  else log_ok "Hôte bitbucket.org déjà dans $PROJETS_KNOWN_HOSTS."; fi
}

# --- mkcert (D5) ------------------------------------------------------------------------------

# _projets_ca_ok : autorité de mkcert créée et présente dans le magasin du système.
_projets_ca_ok() {
  local caroot
  caroot=$(mkcert -CAROOT 2>/dev/null) || return 1
  [[ -f $caroot/rootCA.pem ]] || return 1
  compgen -G "$PROJETS_CA_DIR/mkcert_development_CA_*.crt" >/dev/null
}

_projets_mkcert() {
  if _projets_ca_ok; then log_ok "Autorité mkcert déjà installée."; return 0; fi
  run mkcert -install || { log_error "mkcert -install a échoué : voir le journal."; return 1; }
  _projets_ca_ok || { log_error "Autorité mkcert absente du magasin du système après mkcert -install."; return 1; }
  log_ok "Autorité mkcert installée."
}

# --- Domaines locaux (D6) ---------------------------------------------------------------------

# _projets_host_present <domaine> : une ligne active de /etc/hosts le nomme.
_projets_host_present() {
  awk -v d="$1" '
    /^[[:space:]]*#/ { next }
    { for (i = 2; i <= NF; i++) { if ($i ~ /^#/) break; if ($i == d) f = 1 } }
    END { exit !f }' "$PROJETS_HOSTS_FILE" 2>/dev/null
}

# _projets_hosts [--ask-sudo] : ajoute les domaines manquants du champ hosts.
# --ask-sudo (commandes) : `sudo -v` juste avant la première écriture. Rend 1 si
# une écriture échoue ; un champ absent, vide ou illisible n'est pas une erreur.
_projets_hosts() {
  local ask=${1:-} rc=0 d missing=()
  _projets_read "$PROJETS_HOSTS_REF" || rc=$?
  case $rc in
    0) ;;
    3) log_info "Projets : aucun domaine local (champ « hosts » absent)."; return 0 ;;
    *) log_warn "Projets : domaines locaux illisibles dans 1Password (« $PROJETS_HOSTS_REF »)."; return 0 ;;
  esac
  for d in ${_PROJ_VALUE//,/ }; do
    [[ $d =~ $PROJETS_HOST_RE ]] || { log_warn "Projets : domaine local refusé (forme invalide) : $d"; continue; }
    _projets_host_present "$d" || missing+=("$d")
  done
  (( ${#missing[@]} )) || { log_ok "Domaines locaux déjà dans $PROJETS_HOSTS_FILE."; return 0; }
  if [[ $ask == --ask-sudo ]]; then
    log_info "Mot de passe sudo pour ajouter ${#missing[@]} domaine(s) à $PROJETS_HOSTS_FILE."
    sudo -v || { log_error "sudo refusé : domaines locaux non ajoutés."; return 1; }
  fi
  for d in "${missing[@]}"; do
    # Domaine en argument, jamais interprété ; pas de « | tee » : run ferme stdin.
    # shellcheck disable=SC2016  # $1 et $2 sont ceux du sh lancé par sudo
    run_sudo sh -c 'printf "127.0.0.1\t%s\n" "$1" >>"$2"' _ "$d" "$PROJETS_HOSTS_FILE" \
      || { log_error "Ajout de $d à $PROJETS_HOSTS_FILE impossible."; return 1; }
    log_ok "Domaine local ajouté : $d → 127.0.0.1"
  done
}

# --- Accès legacy (D7) ------------------------------------------------------------------------

# _projets_ssh_include : ligne d'inclusion avant tout bloc Host de ~/.ssh/config
# (placée après un Host, elle ne vaudrait que pour lui).
_projets_ssh_include() {
  local tmp mode=600
  if [[ -f $PROJETS_SSH_CONFIG ]]; then
    grep -qxF -- "$PROJETS_SSH_INCLUDE" "$PROJETS_SSH_CONFIG" && return 0
    mode=$(stat -c %a -- "$PROJETS_SSH_CONFIG") || return 1
  fi
  tmp=$(mktemp -- "$PROJETS_SSH_DIR/.config.XXXXXX") || return 1
  { printf '%s\n' "$PROJETS_SSH_INCLUDE"
    [[ -f $PROJETS_SSH_CONFIG ]] && { printf '\n'; cat -- "$PROJETS_SSH_CONFIG"; }
  } >"$tmp" || { rm -f -- "$tmp"; return 1; }
  if ! chmod "$mode" -- "$tmp" || ! mv -f -- "$tmp" "$PROJETS_SSH_CONFIG"; then
    rm -f -- "$tmp"; return 1
  fi
  log_ok "Inclusion de ~/.ssh/config.d ajoutée en tête de $PROJETS_SSH_CONFIG."
}

# _projets_write_if_changed <fichier> <contenu> <mode> : écrit (umask 077) si différent.
_projets_write_if_changed() {
  [[ -f $1 && $(<"$1") == "$2" ]] && return 1
  ( umask 077; printf '%s\n' "$2" >"$1" ) && chmod "$3" -- "$1"
}

_projets_legacy() {
  local pub notes key
  _projets_ssh_dir
  _projets_read "$PROJETS_LEGACY_ITEM/public key" && pub=$_PROJ_VALUE || pub=""
  _projets_read "$PROJETS_LEGACY_ITEM/notesPlain" && notes=$_PROJ_VALUE || notes=""
  if [[ -z $pub || -z ${notes//[[:space:]]/} ]]; then
    log_warn "Projets : clé SSH legacy illisible ou incomplète dans 1Password (« $PROJETS_LEGACY_ITEM »)."
    manual_step "$PROJETS_LEGACY_MANUAL"
    return 0
  fi
  _projets_write_if_changed "$PROJETS_LEGACY_KEY.pub" "$pub" 0644 \
    && log_ok "Clé publique legacy écrite : $PROJETS_LEGACY_KEY.pub"
  if _projets_agent_available; then
    log_info "Clé legacy servie par l'agent 1Password : aucune clé privée écrite."
  elif [[ -f $PROJETS_LEGACY_KEY ]]; then
    log_ok "Clé privée legacy déjà présente : $PROJETS_LEGACY_KEY (laissée intacte)."
  else
    # Jamais affichée ni journalisée : lue dans une variable, écrite en 0600.
    if ! _projets_read "$PROJETS_LEGACY_ITEM/private key?ssh-format=openssh" || [[ -z $_PROJ_VALUE ]]; then
      log_warn "Projets : clé privée legacy illisible dans 1Password."
      manual_step "$PROJETS_LEGACY_MANUAL"
      return 0
    fi
    key=$_PROJ_VALUE; _PROJ_VALUE=""
    if ! ( umask 077; printf '%s\n' "$key" >"$PROJETS_LEGACY_KEY" ) || ! chmod 0600 -- "$PROJETS_LEGACY_KEY"; then
      unset key; return 1
    fi
    unset key
    log_ok "Clé privée legacy écrite depuis 1Password : $PROJETS_LEGACY_KEY"
  fi
  [[ -d $PROJETS_SSH_CONF_DIR ]] || { mkdir -- "$PROJETS_SSH_CONF_DIR" && chmod 0700 -- "$PROJETS_SSH_CONF_DIR"; } || return 1
  _projets_write_if_changed "$PROJETS_SSH_CONF" "$notes" 0600 \
    && log_ok "Configuration SSH legacy écrite : $PROJETS_SSH_CONF"
  _projets_ssh_include
}

# _projets_legacy_ok : accès legacy en place (D11), sans 1Password.
_projets_legacy_ok() {
  [[ -f $PROJETS_LEGACY_KEY.pub && -s $PROJETS_SSH_CONF ]] || return 1
  _projets_agent_available || [[ -f $PROJETS_LEGACY_KEY ]] || return 1
  grep -qxF -- "$PROJETS_SSH_INCLUDE" "$PROJETS_SSH_CONFIG" 2>/dev/null
}

# --- Contrat de module ------------------------------------------------------------------------

# Déjà fait = au moins un dépôt, bitbucket.org connu, mkcert et son autorité,
# accès legacy (D11). Sans sudo, réseau ni 1Password : ni l'arbre ni les
# domaines ne sont vérifiés (--pull-projets s'en charge).
module_check() {
  [[ -n $(find "$PROJETS_ROOT" -maxdepth 6 -name node_modules -prune -o -type d -name .git -print -quit 2>/dev/null) ]] || return 1
  ssh-keygen -F bitbucket.org -f "$PROJETS_KNOWN_HOSTS" >/dev/null 2>&1 || return 1
  pkg_installed mkcert && pkg_installed libnss3-tools || return 1
  _projets_ca_ok || return 1
  _projets_legacy_ok
}

module_install() {
  apt_install mkcert libnss3-tools
}

# Hôte Bitbucket avant les clones ; tout est tenté, le premier échec est rendu
# à la fin (un clonage en échec fait échouer le module, D3).
module_configure() {
  local failed=0 rc=0
  _projets_env
  _projets_known_hosts || failed=1
  _projets_mkcert || failed=1
  _projets_load_tree || rc=$?
  if (( rc == 0 )); then
    _projets_clone_all || failed=1
    (( ${#_PROJ_CLONED[@]} )) && log_ok "Projets : ${#_PROJ_CLONED[@]} dépôt(s) cloné(s)."
    _projets_hosts || failed=1
  else
    manual_step "$PROJETS_SNAPSHOT_MANUAL"
  fi
  if op_session_active; then _projets_legacy || failed=1
  elif ! _projets_legacy_ok; then manual_step "$PROJETS_LEGACY_MANUAL"; fi
  return "$failed"
}

# --- Commandes du runner ------------------------------------------------------------------------

# projets_snapshot : relevé des dépôts sous ~/projets vers 1Password (D8).
projets_snapshot() {
  local d rel url kept k tree="" n=0 skip
  local -a found=() repos=()
  [[ -d $PROJETS_ROOT ]] || { log_error "Relevé impossible : $PROJETS_ROOT n'existe pas."; return 1; }
  op_session_active || { log_error "Relevé impossible : aucune session 1Password."; return 1; }
  while IFS= read -r d; do found+=("${d%/.git}"); done < <(
    find "$PROJETS_ROOT" -name node_modules -prune -o -type d -name .git -print 2>/dev/null | LC_ALL=C sort)
  # Dépôts imbriqués écartés : -prune sur .git n'élague pas ses frères.
  for d in "${found[@]}"; do
    skip=0
    for k in "${repos[@]}"; do [[ $d == "$k"/* ]] && { skip=1; break; }; done
    (( skip )) && { log_info "Relevé : dépôt imbriqué ignoré : ${d#"$HOME"/}"; continue; }
    repos+=("$d")
  done
  for d in "${repos[@]}"; do
    rel=${d#"$HOME"/}
    if ! url=$(git -C "$d" remote get-url origin 2>/dev/null) || [[ -z $url ]]; then
      log_warn "Relevé : $rel n'a pas de dépôt origin, laissé hors de l'arbre."; continue
    fi
    if ! _projets_valid_path "$rel" || ! [[ $url =~ $PROJETS_URL_RE ]]; then
      log_warn "Relevé : $rel ou son origin a une forme refusée par le module, laissé hors de l'arbre."; continue
    fi
    tree+="$rel"$'\t'"$url"$'\n'; n=$((n + 1))
    log_info "Relevé : $rel"
  done
  tree=${tree%$'\n'}
  (( n )) || { log_error "Relevé : aucun dépôt git sous $PROJETS_ROOT."; return 1; }
  if _projets_read "$PROJETS_TREE_REF" && [[ $_PROJ_VALUE == "$tree" ]]; then
    log_ok "Arbre inchangé ($n dépôt(s)) : rien d'écrit dans 1Password."; return 0
  fi
  if op item get "$PROJETS_OP_TITLE" --vault "$PROJETS_OP_VAULT" >/dev/null 2>>"$LOG_FILE"; then
    op item edit "$PROJETS_OP_TITLE" --vault "$PROJETS_OP_VAULT" "notesPlain=$tree" >/dev/null 2>>"$LOG_FILE" \
      || { log_error "Écriture de l'arbre dans 1Password impossible (voir le journal)."; return 1; }
  else
    op item create --category "Secure Note" --title "$PROJETS_OP_TITLE" --vault "$PROJETS_OP_VAULT" "notesPlain=$tree" >/dev/null 2>>"$LOG_FILE" \
      || { log_error "Création de l'élément « $PROJETS_OP_TITLE » impossible (voir le journal)."; return 1; }
  fi
  _projets_read "$PROJETS_TREE_REF" && [[ $_PROJ_VALUE == "$tree" ]] \
    || { log_error "Arbre relu dans 1Password différent de celui écrit."; return 1; }
  log_ok "Arbre des projets écrit dans 1Password : $n dépôt(s) (« $PROJETS_TREE_REF »)."
}

# projets_pull : relit l'arbre, clone ce qui manque, domaines, avance rapide des
# clones propres qui suivent une branche distante (D9). Rend 1 sur un échec.
projets_pull() {
  local i rc path dir ahead behind dirty
  local -a updated=() current=() cloned=() skipped=() failures=()
  _projets_env
  _projets_load_tree || { log_error "Mise à jour impossible : arbre des projets illisible."; return 1; }
  _projets_hosts --ask-sudo || failures+=("/etc/hosts : ajout des domaines locaux")
  for i in "${!TREE_PATHS[@]}"; do
    path=${TREE_PATHS[i]} dir=$HOME/${TREE_PATHS[i]}
    rc=0; _projets_clone "$path" "${TREE_URLS[i]}" || rc=$?
    case $rc in
      10) cloned+=("$path"); _projets_setup_step "$path"; continue ;;
      0) ;;
      *) failures+=("$path : clonage ou dossier étranger"); continue ;;
    esac
    if ! git -C "$dir" fetch --prune --quiet >>"$LOG_FILE" 2>&1 </dev/null; then
      failures+=("$path : récupération (fetch)"); continue
    fi
    dirty=$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)
    [[ -z $dirty ]] || { skipped+=("$path : modifications en cours"); continue; }
    git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 \
      || { skipped+=("$path : sans branche suivie"); continue; }
    read -r ahead behind < <(git -C "$dir" rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null)
    if (( ahead == 0 && behind == 0 )); then current+=("$path")
    elif (( ahead == 0 )); then
      if git -C "$dir" merge --ff-only --quiet '@{u}' >>"$LOG_FILE" 2>&1 </dev/null; then updated+=("$path")
      else failures+=("$path : avance rapide refusée (voir le journal)"); fi
    elif (( behind == 0 )); then skipped+=("$path : en avance ($ahead commit(s) non poussé(s))")
    else skipped+=("$path : divergé ($ahead en avance, $behind en retard)"); fi
  done
  log_info "Projets : ${#updated[@]} mis à jour, ${#current[@]} déjà à jour, ${#cloned[@]} cloné(s), ${#skipped[@]} laissé(s) de côté, ${#failures[@]} échec(s)."
  for i in "${updated[@]}"; do log_ok "Mis à jour : $i"; done
  for i in "${cloned[@]}"; do log_ok "Cloné : $i"; done
  for i in "${skipped[@]}"; do log_warn "Laissé de côté : $i"; done
  for i in "${failures[@]}"; do log_error "Échec : $i"; done
  (( ${#failures[@]} == 0 ))
}
