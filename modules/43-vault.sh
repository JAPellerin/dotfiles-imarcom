#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/43-vault.sh — CLI Vault de HashiCorp, réglée pour le serveur d'Imarcom,
# et connexion LDAP avec les identifiants de 1Password : les projets lisent leurs
# secrets dans Vault sans poser de question (client : `make env-vault`).
#
# Suit la doc officielle :
#   https://developer.hashicorp.com/vault/install          (onglet Ubuntu/Debian)
#   https://developer.hashicorp.com/vault/docs/auth/ldap   (connexion LDAP)
# Le dépôt est déclaré en deb822 par le socle ; un ancien `.list` de la doc de
# HashiCorp (deux `Signed-By` pour un même dépôt : apt refuse) est retiré avant
# (D2). VAULT_ADDR vient du fragment config/vault/commonrc.sh (D3). « Déjà fait »
# inclut un jeton de moins de 30 jours, constaté hors ligne (D4) ; mot de passe
# et jeton passent par l'entrée standard, jamais en argument ni au journal (D5).
# Vault injoignable (adresse privée : réseau de l'entreprise ou VPN) ou 1Password
# indisponible : étape manuelle, jamais d'échec.
# Voir openspec/specs/module-vault/spec.md et openspec/changes/archive/2026-09-28-vault/design.md.
MODULE_NAME="vault"
MODULE_DESC="CLI Vault (dépôt HashiCorp) ; VAULT_ADDR d'Imarcom ; connexion LDAP depuis 1Password"
MODULE_GROUP="dev"
MODULE_DEPS="base shell 1password"

VAULT_KEY_URL="https://apt.releases.hashicorp.com/gpg"
VAULT_REPO_URL="https://apt.releases.hashicorp.com"
VAULT_REPO_HOST="apt.releases.hashicorp.com"
# Emplacements de l'ancienne déclaration (doc de HashiCorp) ; surchargeables (tests).
VAULT_LEGACY_KEY="${VAULT_LEGACY_KEY:-/usr/share/keyrings/hashicorp-archive-keyring.gpg}"
VAULT_APT_MAIN_LIST="${VAULT_APT_MAIN_LIST:-/etc/apt/sources.list}"
VAULT_ADDR_URL="https://vault.imarcom.net"
VAULT_FRAGMENT="config/vault/commonrc.sh"
VAULT_FRAGMENT_TARGET="$SHELL_COMMON_RC_DIR/vault.sh"
# Là où l'assistant de jeton de la CLI l'écrit ; surchargeable (tests).
VAULT_TOKEN_FILE="${VAULT_TOKEN_FILE:-$HOME/.vault-token}"
# Jeton LDAP émis pour 32 jours (relevé du 28 sept 2026) : deux jours de marge.
VAULT_TOKEN_MAX_AGE_DAYS=30
# Délai de `vault status` quand Vault ne répond pas (relevé 0.2 c).
VAULT_STATUS_TIMEOUT=5
VAULT_OP_ITEM="op://Imarcom/Vault"
VAULT_USER_REF="$VAULT_OP_ITEM/username"
VAULT_PASSWORD_REF="$VAULT_OP_ITEM/password"
VAULT_LOGIN_MANUAL="Se connecter à Vault (réseau de l'entreprise ou VPN actif) : vault login -method=ldap username=<identifiant>"

# _vault_repo_count <fichier> : « <lignes HashiCorp> <autres lignes> » parmi les
# lignes actives (ni vides ni commentées) ; fichier illisible → « 0 0 ».
_vault_repo_count() {
  awk -v h="$VAULT_REPO_HOST" '
    /^[[:space:]]*(#|$)/ { next }
    { if (index($0, h)) hc++; else oc++ }
    END { print hc + 0, oc + 0 }' "$1" 2>/dev/null || printf '0 0\n'
}

# _vault_legacy_lists : fichiers au format `.list` (sources.list.d et
# /etc/apt/sources.list) dont une ligne active désigne le dépôt de HashiCorp,
# un par ligne. Lecture seule, sans sudo (D2, D6).
_vault_legacy_lists() {
  local f hc oc
  for f in "$APT_SOURCES_DIR"/*.list "$VAULT_APT_MAIN_LIST"; do
    [[ -f $f ]] || continue
    read -r hc oc < <(_vault_repo_count "$f")
    (( hc > 0 )) && printf '%s\n' "$f"
  done
  return 0
}

# _vault_remove_legacy : retire les `.list` qui ne déclarent que HashiCorp, puis
# l'ancienne clé si plus rien ne la cite (D2). Un fichier mêlé → échec nommé,
# rien de retiré.
_vault_remove_legacy() {
  local f hc oc removed=0 lists
  lists=$(_vault_legacy_lists)
  while IFS= read -r f; do
    [[ -n $f ]] || continue
    read -r hc oc < <(_vault_repo_count "$f")
    if (( oc > 0 )) || [[ $f == "$VAULT_APT_MAIN_LIST" ]]; then
      log_error "Vault : $f déclare le dépôt de HashiCorp avec d'autres dépôts ; retirer à la main sa ligne de HashiCorp, puis relancer."
      return 1
    fi
  done <<<"$lists"
  while IFS= read -r f; do
    [[ -n $f ]] || continue
    run_sudo rm -f -- "$f" || return 1
    log_info "Ancienne déclaration du dépôt de HashiCorp retirée : $f"
    removed=1
  done <<<"$lists"
  if [[ -e $VAULT_LEGACY_KEY ]] \
     && ! grep -rqsF -- "$VAULT_LEGACY_KEY" "$APT_SOURCES_DIR" "$VAULT_APT_MAIN_LIST"; then
    run_sudo rm -f -- "$VAULT_LEGACY_KEY" || return 1
    log_info "Ancienne clé du dépôt de HashiCorp retirée : $VAULT_LEGACY_KEY"
    removed=1
  fi
  (( removed )) && apt_mark_stale
  return 0
}

# _vault_token_fresh : vrai si le jeton existe, non vide, et date de moins de
# VAULT_TOKEN_MAX_AGE_DAYS jours (D4). Hors ligne ; ni tube ni grep -q.
_vault_token_fresh() {
  [[ -s $VAULT_TOKEN_FILE ]] || return 1
  [[ -n $(find "$VAULT_TOKEN_FILE" -maxdepth 0 -mmin "-$(( VAULT_TOKEN_MAX_AGE_DAYS * 24 * 60 ))" 2>/dev/null) ]]
}

# _vault_manual <avertissement> : empêchement → étape manuelle, sans échec.
_vault_manual() {
  log_warn "$1"
  manual_step "$VAULT_LOGIN_MANUAL"
  return 0
}

# _vault_login : connexion LDAP depuis 1Password si le jeton manque ou est ancien
# (D5). Rend 1 seulement si le jeton obtenu n'a pas pu être enregistré.
_vault_login() {
  local rc=0 user password token
  if _vault_token_fresh; then
    log_ok "Jeton Vault de moins de $VAULT_TOKEN_MAX_AGE_DAYS jours : aucune connexion."
    return 0
  fi
  # 1. Serveur joignable (adresse privée).
  printf '[%s] $ vault status (VAULT_ADDR=%s)\n' "$(date +%H:%M:%S)" "$VAULT_ADDR_URL" >>"$LOG_FILE"
  VAULT_ADDR=$VAULT_ADDR_URL VAULT_CLIENT_TIMEOUT=$VAULT_STATUS_TIMEOUT \
    vault status >>"$LOG_FILE" 2>&1 </dev/null || rc=$?
  case $rc in
    0) ;;
    2) _vault_manual "Vault est scellé ($VAULT_ADDR_URL) : connexion impossible pour l'instant."; return ;;
    *) _vault_manual "Vault injoignable ($VAULT_ADDR_URL : réseau de l'entreprise ou VPN requis)."; return ;;
  esac
  # 2. Identifiants dans 1Password.
  op_session_active || { _vault_manual "Vault : aucune session 1Password, identifiants illisibles."; return; }
  user=$(op_read "$VAULT_USER_REF" 2>>"$LOG_FILE") || user=""
  [[ -n $user ]] || { _vault_manual "Vault : identifiant illisible dans 1Password (« $VAULT_USER_REF »)."; return; }
  password=$(op_read "$VAULT_PASSWORD_REF" 2>>"$LOG_FILE") || password=""
  [[ -n $password ]] || { _vault_manual "Vault : mot de passe illisible dans 1Password (« $VAULT_PASSWORD_REF »)."; return; }
  # 3. Jeton : mot de passe par l'entrée standard (« - »), jamais en argument ;
  #    ni run ni ui_spin, qui traceraient la commande. Trace écrite à la main.
  printf '[%s] $ vault write -field=token auth/ldap/login/%s password=- (mot de passe par l'"'"'entrée standard)\n' \
    "$(date +%H:%M:%S)" "$user" >>"$LOG_FILE"
  token=$(printf '%s' "$password" \
    | VAULT_ADDR=$VAULT_ADDR_URL vault write -field=token "auth/ldap/login/$user" password=- 2>>"$LOG_FILE") || token=""
  unset password
  [[ -n $token ]] || { _vault_manual "Vault : connexion refusée pour « $user » (voir le journal) ; jeton existant conservé."; return; }
  # 4. Enregistrement par l'assistant de jeton de la CLI (~/.vault-token, 0600).
  printf '[%s] $ vault login -no-print - (jeton par l'"'"'entrée standard)\n' "$(date +%H:%M:%S)" >>"$LOG_FILE"
  if ! printf '%s' "$token" | VAULT_ADDR=$VAULT_ADDR_URL vault login -no-print - >/dev/null 2>>"$LOG_FILE"; then
    unset token
    log_error "Jeton Vault obtenu mais non enregistré (voir le journal)."
    return 1
  fi
  unset token
  _vault_token_fresh || { log_error "Jeton Vault non enregistré : $VAULT_TOKEN_FILE absent ou vide."; return 1; }
  log_ok "Connecté à Vault ($user) : jeton enregistré."
}

# Déjà fait = paquet installé, aucune ancienne déclaration `.list` du dépôt,
# fragment lié et jeton récent (D6). Sans sudo, réseau ni 1Password.
module_check() {
  pkg_installed vault || return 1
  [[ -z $(_vault_legacy_lists) ]] || return 1
  config_linked "$VAULT_FRAGMENT" "$VAULT_FRAGMENT_TARGET" || return 1
  _vault_token_fresh
}

# Ancienne déclaration retirée avant le dépôt du socle (sinon apt update échoue),
# puis paquet (seulement s'il manque).
module_install() {
  _vault_remove_legacy || return 1
  apt_add_repo hashicorp "$VAULT_KEY_URL" "$VAULT_REPO_URL" auto main || return 1
  apt_install vault
}

# Fragment (VAULT_ADDR dans les shells, avis si le shell courant ne l'a pas),
# puis connexion si le jeton manque ou est ancien. Constat refait ici : install et configure tournent dans deux sous-shells.
module_configure() {
  link_config "$VAULT_FRAGMENT" "$VAULT_FRAGMENT_TARGET" || return 1
  # Le shell qui a lancé le script ne voit pas le fragment : sans VAULT_ADDR, la
  # CLI vise 127.0.0.1:8200 (« connection refused »), d'où l'avis (D3).
  [[ ${VAULT_ADDR:-} == "$VAULT_ADDR_URL" ]] \
    || log_info "VAULT_ADDR : ouvrir un nouveau terminal (ou « source $VAULT_FRAGMENT_TARGET ») avant d'utiliser vault."
  _vault_login
}
