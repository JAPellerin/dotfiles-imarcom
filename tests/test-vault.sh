#!/usr/bin/env bash
# tests/test-vault.sh — module vault avec des doublures : dpkg-query lu dans un
# fichier ; run_sudo qui journalise, simule apt-get install et applique `rm -f`
# dans une racine du dossier temporaire ; apt_add_repo qui compte ; op (session et
# lectures sur drapeaux, lectures tracées) ; vault factice (status : code sur
# drapeau ; write : lit le mot de passe sur son entrée standard, trace ses seuls
# arguments, rend un jeton ou refuse ; login : lit le jeton sur son entrée
# standard et l'écrit dans VAULT_TOKEN_FILE). Les fonctions du module sont
# appelées par module_call, chacune dans son sous-shell, comme le fait le runner.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"
mkdir -p "$TEST_TMP/bin" "$TEST_TMP/home"
export HOME="$TEST_TMP/home"
SHELL_COMMON_RC_DIR="$HOME/.commonrc.d"
export FAKE_DIR="$TEST_TMP"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
VAULT_ARGS="$TEST_TMP/vault-args"
# Racine apt du test : sources.list.d, sources.list et l'ancienne clé.
APT_SOURCES_DIR="$TEST_TMP/racine/etc/apt/sources.list.d"
export VAULT_APT_MAIN_LIST="$TEST_TMP/racine/etc/apt/sources.list"
export VAULT_LEGACY_KEY="$TEST_TMP/racine/usr/share/keyrings/hashicorp-archive-keyring.gpg"
export VAULT_TOKEN_FILE="$HOME/.vault-token"
MOD="$DOTFILES_DIR/modules/43-vault.sh"
export JETON='hvs.JETON-FACTICE-42'
REPO_CALL="apt_add_repo hashicorp https://apt.releases.hashicorp.com/gpg https://apt.releases.hashicorp.com auto main"
LEGACY_LINE="deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com resolute main"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
# op : session si $FAKE_DIR/session ; lectures tracées dans calls ; drapeaux
# op-user-refuse (identifiant illisible) et op-pass-empty (mot de passe vide).
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read) printf 'op read %s\n' "${*: -1}" >>"$FAKE_DIR/calls"
        case ${*: -1} in
          op://Imarcom/Vault/username)
            [[ -e $FAKE_DIR/op-user-refuse ]] && { echo "[ERROR] item 'Imarcom/Vault' does not have a field 'username'" >&2; exit 1; }
            printf 'jean.test' ;;
          op://Imarcom/Vault/password)
            [[ -e $FAKE_DIR/op-pass-empty ]] && exit 0
            printf '%s' 'Mdp-Vault,4\x:9' ;;
          *) echo "[ERROR] introuvable" >&2; exit 1 ;;
        esac ;;
esac
FAKE
# vault : arguments tracés dans vault-args (jamais l'entrée standard) ; status →
# code de $FAKE_DIR/vault-status (0 par défaut) ; write → contrôle le mot de passe
# reçu sur l'entrée standard, rend le jeton, ou refuse (vault-refuse) ; login →
# lit le jeton sur l'entrée standard et l'écrit en 0600 (login-refuse : échec).
cat >"$TEST_TMP/bin/vault" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_DIR/vault-args"
case $1 in
  status) exit "$(cat "$FAKE_DIR/vault-status" 2>/dev/null || echo 0)" ;;
  write)
    input=$(cat)
    [[ $input == 'Mdp-Vault,4\x:9' ]] && echo "mot de passe reçu" >>"$FAKE_DIR/vault-stdin"
    [[ -e $FAKE_DIR/vault-refuse ]] && { echo "Error writing data to auth/ldap/login/jean.test: Code: 400. ldap operation failed" >&2; exit 2; }
    printf '%s\n' "$JETON" ;;
  login)
    input=$(cat)
    [[ -e $FAKE_DIR/login-refuse ]] && { echo "Error: token lookup failed" >&2; exit 2; }
    (umask 077; printf '%s' "$input" >"$VAULT_TOKEN_FILE") ;;
  *) exit 3 ;;
esac
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

# Doublures, héritées par les sous-shells de module_call.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  case "${args[0]} ${args[1]:-}" in
    "apt-get install")
      for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done ;;
    "rm -f") command rm -f "${args[@]:2}" ;;   # chemins du dossier temporaire
  esac
  return 0
}
apt_add_repo() { printf 'apt_add_repo %s\n' "$*" >>"$CALLS"; }
export -f run_sudo apt_add_repo
export INSTALLED CALLS TEST_TMP
_APT_UPDATED=1; export _APT_UPDATED
line_of() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }
mcall() { module_call "$MOD" "$1"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }
vault_calls() { grep -c -- "$1" "$VAULT_ARGS" 2>/dev/null || true; }
LOGIN_STEP="Se connecter à Vault"
# reset_apt : racine apt vide, sans ancienne déclaration.
reset_apt() {
  rm -rf "$TEST_TMP/racine"
  mkdir -p "$APT_SOURCES_DIR" "$(dirname -- "$VAULT_LEGACY_KEY")"
  printf 'deb http://archive.ubuntu.com/ubuntu resolute main\n' >"$VAULT_APT_MAIN_LIST"
  : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; : >"$LOG_FILE"
}
# reset_login : ni jeton ni drapeau, session active, Vault joignable.
reset_login() {
  rm -f "$VAULT_TOKEN_FILE" "$TEST_TMP"/{vault-status,vault-refuse,login-refuse,op-user-refuse,op-pass-empty,vault-stdin}
  touch "$TEST_TMP/session"
  : >"$CALLS"; : >"$MANUAL_STEPS_FILE"; : >"$LOG_FILE"; : >"$VAULT_ARGS"
}
old_token() { printf 'hvs.ANCIEN' >"$VAULT_TOKEN_FILE"; touch -d "$1 days ago" "$VAULT_TOKEN_FILE"; }

printf '%s\n' "== métadonnées =="
deps=$(bash -c 'source "$1"; printf "%s" "$MODULE_DEPS"' _ "$MOD")
assert_contains "dépend de shell (fragment chargé par ~/.commonrc)" "$deps" "shell"
assert_contains "dépend de 1password (scénario « Lancé seul »)" "$deps" "1password"
assert_eq "module non graphique (WSL)" "" "$(bash -c 'source "$1"; printf "%s" "${MODULE_NEEDS_GUI:-}"' _ "$MOD")"

printf '%s\n' "== première installation, aucune ancienne déclaration =="
reset_apt; reset_login
assert_fail "module_check → à faire" mcall module_check
mcall module_install >/dev/null 2>&1; rc=$?
assert_eq "module_install réussit" 0 "$rc"
assert_contains "dépôt de HashiCorp, suite du système, composant main" "$(cat "$CALLS")" "$REPO_CALL"
assert_ok "dépôt déclaré avant le paquet" test "$(line_of apt_add_repo)" -lt "$(line_of 'apt-get install')"
assert_contains "paquet vault installé" "$(cat "$INSTALLED")" "vault"
assert_eq "rien de retiré" 0 "$(count_calls 'rm -f')"
assert_eq "sources.list intact" "deb http://archive.ubuntu.com/ubuntu resolute main" "$(cat "$VAULT_APT_MAIN_LIST")"

printf '%s\n' "== ancienne déclaration de la doc de HashiCorp =="
reset_apt
printf '%s\n' "$LEGACY_LINE" >"$APT_SOURCES_DIR/hashicorp.list"
printf 'deb https://download.docker.com/linux/ubuntu resolute stable\n' >"$APT_SOURCES_DIR/autre.list"
printf 'clé' >"$VAULT_LEGACY_KEY"
assert_fail "module_check : ancien .list → à faire" mcall module_check
assert_ok "module_install réussit" mcall module_install
assert_fail "ancien .list retiré" test -e "$APT_SOURCES_DIR/hashicorp.list"
assert_fail "ancienne clé retirée" test -e "$VAULT_LEGACY_KEY"
assert_ok "autre .list intact" test -s "$APT_SOURCES_DIR/autre.list"
assert_ok "retrait avant la déclaration du socle" test "$(line_of 'rm -f')" -lt "$(line_of apt_add_repo)"
assert_eq "paquet déjà installé : non repassé à apt" 0 "$(count_calls 'apt-get install')"

printf '%s\n' "== ancienne clé encore citée ailleurs =="
reset_apt
printf '%s\n' "$LEGACY_LINE" >"$APT_SOURCES_DIR/hashicorp.list"
printf 'Types: deb\nSigned-By: %s\n' "$VAULT_LEGACY_KEY" >"$APT_SOURCES_DIR/autre.sources"
printf 'clé' >"$VAULT_LEGACY_KEY"
assert_ok "module_install réussit" mcall module_install
assert_fail "ancien .list retiré" test -e "$APT_SOURCES_DIR/hashicorp.list"
assert_ok "clé citée par un .sources → gardée" test -e "$VAULT_LEGACY_KEY"
reset_apt
printf '%s\n' "$LEGACY_LINE" >"$APT_SOURCES_DIR/hashicorp.list"
printf '# %s\ndeb [signed-by=%s] http://exemple.invalid x main\n' "commentaire" "$VAULT_LEGACY_KEY" >>"$VAULT_APT_MAIN_LIST"
printf 'clé' >"$VAULT_LEGACY_KEY"
assert_ok "module_install réussit" mcall module_install
assert_ok "clé citée par /etc/apt/sources.list → gardée" test -e "$VAULT_LEGACY_KEY"

printf '%s\n' "== ancienne déclaration mêlée à d'autres dépôts =="
reset_apt
printf '%s\ndeb http://exemple.invalid x main\n' "$LEGACY_LINE" >"$APT_SOURCES_DIR/melange.list"
printf 'clé' >"$VAULT_LEGACY_KEY"
out=$(mcall module_install 2>&1); rc=$?
assert_eq "module_install échoue" 1 "$rc"
assert_contains "échec qui nomme le fichier" "$out" "$APT_SOURCES_DIR/melange.list"
assert_eq "fichier intact" 2 "$(wc -l <"$APT_SOURCES_DIR/melange.list")"
assert_ok "clé intacte" test -e "$VAULT_LEGACY_KEY"
assert_eq "dépôt non déclaré une seconde fois" 0 "$(count_calls apt_add_repo)"
reset_apt
printf '%s\n' "$LEGACY_LINE" >>"$VAULT_APT_MAIN_LIST"
out=$(mcall module_install 2>&1); rc=$?
assert_eq "ligne HashiCorp dans sources.list → échec" 1 "$rc"
assert_contains "échec qui nomme sources.list" "$out" "$VAULT_APT_MAIN_LIST"
assert_eq "sources.list intact" 2 "$(wc -l <"$VAULT_APT_MAIN_LIST")"
assert_eq "dépôt non déclaré" 0 "$(count_calls apt_add_repo)"
reset_apt
printf '# %s\n' "$LEGACY_LINE" >"$APT_SOURCES_DIR/commente.list"
assert_ok "ligne HashiCorp commentée → ignorée" mcall module_install
assert_ok "fichier commenté intact" test -e "$APT_SOURCES_DIR/commente.list"
rm -f "$APT_SOURCES_DIR/commente.list"

printf '%s\n' "== connexion depuis 1Password =="
reset_apt; reset_login
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_ok "fragment lié" config_linked config/vault/commonrc.sh "$SHELL_COMMON_RC_DIR/vault.sh"
assert_eq "jeton enregistré" "$JETON" "$(cat "$VAULT_TOKEN_FILE")"
assert_eq "jeton lisible par l'utilisateur seul" 600 "$(stat -c %a "$VAULT_TOKEN_FILE")"
assert_eq "mot de passe reçu sur l'entrée standard de vault write" "mot de passe reçu" "$(cat "$TEST_TMP/vault-stdin" 2>/dev/null)"
assert_contains "connexion LDAP pour l'identifiant de l'élément" "$(cat "$VAULT_ARGS")" "write -field=token auth/ldap/login/jean.test password=-"
assert_contains "jeton enregistré par vault login" "$(cat "$VAULT_ARGS")" "login -no-print -"
assert_eq "aucune étape manuelle" "" "$(cat "$MANUAL_STEPS_FILE")"
assert_not_contains "mot de passe absent de la sortie" "$out" "Mdp-Vault"
assert_not_contains "mot de passe absent du journal" "$(cat "$LOG_FILE")" "Mdp-Vault"
assert_not_contains "mot de passe absent des arguments de vault" "$(cat "$VAULT_ARGS")" "Mdp-Vault"
assert_not_contains "jeton absent de la sortie" "$out" "JETON-FACTICE"
assert_not_contains "jeton absent du journal" "$(cat "$LOG_FILE")" "JETON-FACTICE"
assert_not_contains "jeton absent des arguments de vault" "$(cat "$VAULT_ARGS")" "JETON-FACTICE"
assert_contains "trace de la connexion au journal, sans secret" "$(cat "$LOG_FILE")" "auth/ldap/login/jean.test password=- (mot de passe par l'entrée standard)"
printf 'vault\n' >"$INSTALLED"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== avis VAULT_ADDR pour le shell courant =="
reset_login; old_token 1
assert_contains "shell sans VAULT_ADDR → avis" "$(VAULT_ADDR='' mcall module_configure 2>&1)" "VAULT_ADDR : ouvrir un nouveau terminal"
assert_not_contains "shell avec VAULT_ADDR → aucun avis" "$(VAULT_ADDR=https://vault.imarcom.net mcall module_configure 2>&1)" "ouvrir un nouveau terminal"

printf '%s\n' "== jeton récent =="
reset_login; old_token 29; printf 'vault\n' >"$INSTALLED"
assert_ok "jeton de 29 jours : module_check → déjà fait" mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_eq "aucun appel à vault" "" "$(cat "$VAULT_ARGS")"
assert_eq "jeton conservé" "hvs.ANCIEN" "$(cat "$VAULT_TOKEN_FILE")"

printf '%s\n' "== jeton ancien =="
reset_login; old_token 31
assert_fail "jeton de 31 jours : module_check → à faire" mcall module_check
assert_ok "module_configure réussit" mcall module_configure
assert_eq "nouveau jeton" "$JETON" "$(cat "$VAULT_TOKEN_FILE")"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== module_check : chacune de ses conditions =="
assert_ok "tout est fait" mcall module_check
: >"$VAULT_TOKEN_FILE"
assert_fail "jeton vide → à faire" mcall module_check
rm -f "$VAULT_TOKEN_FILE"
assert_fail "jeton absent → à faire" mcall module_check
old_token 1
rm -f "$SHELL_COMMON_RC_DIR/vault.sh"
assert_fail "fragment retiré → à faire" mcall module_check
assert_ok "module_configure le rétablit" mcall module_configure
assert_ok "module_check → déjà fait" mcall module_check
: >"$INSTALLED"
assert_fail "paquet absent → à faire" mcall module_check
printf 'vault\n' >"$INSTALLED"
printf '%s\n' "$LEGACY_LINE" >"$APT_SOURCES_DIR/hashicorp.list"
assert_fail "ancien .list → à faire" mcall module_check
rm -f "$APT_SOURCES_DIR/hashicorp.list"
assert_ok "module_check → déjà fait" mcall module_check

# login_manual <cas> <avertissement attendu> : empêchement → étape, retour 0,
# module toujours à faire, jeton existant (ancien) conservé.
login_manual() {
  out=$(mcall module_configure 2>&1); rc=$?
  assert_eq "$1 : module_configure réussit" 0 "$rc"
  assert_contains "$1 : avertissement" "$out" "$2"
  assert_contains "$1 : étape de connexion au résumé" "$(cat "$MANUAL_STEPS_FILE")" "$LOGIN_STEP"
  assert_eq "$1 : ancien jeton conservé" "hvs.ANCIEN" "$(cat "$VAULT_TOKEN_FILE")"
  assert_fail "$1 : module_check → à faire" mcall module_check
  assert_not_contains "$1 : mot de passe absent du journal" "$(cat "$LOG_FILE")" "Mdp-Vault"
}

printf '%s\n' "== empêchements =="
reset_login; old_token 40; printf '1' >"$TEST_TMP/vault-status"
login_manual "injoignable" "Vault injoignable"
assert_eq "injoignable : aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
reset_login; old_token 40; printf '2' >"$TEST_TMP/vault-status"
login_manual "scellé" "Vault est scellé"
assert_eq "scellé : aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
reset_login; old_token 40; rm -f "$TEST_TMP/session"
login_manual "sans session" "aucune session 1Password"
reset_login; old_token 40; touch "$TEST_TMP/op-user-refuse"
login_manual "identifiant illisible" "op://Imarcom/Vault/username"
assert_not_contains "identifiant illisible : aucune erreur de op à l'écran" "$out" "[ERROR]"
reset_login; old_token 40; touch "$TEST_TMP/op-pass-empty"
login_manual "mot de passe vide" "op://Imarcom/Vault/password"
assert_eq "mot de passe vide : aucune connexion tentée" 0 "$(vault_calls "^write")"
reset_login; old_token 40; touch "$TEST_TMP/vault-refuse"
login_manual "connexion refusée" "connexion refusée pour « jean.test »"
assert_eq "connexion refusée : aucun enregistrement tenté" 0 "$(vault_calls "^login")"

printf '%s\n' "== jeton obtenu mais non enregistré =="
reset_login; old_token 40; touch "$TEST_TMP/login-refuse"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure échoue" 1 "$rc"
assert_contains "échec nommé" "$out" "Jeton Vault obtenu mais non enregistré"
assert_not_contains "jeton absent de la sortie" "$out" "JETON-FACTICE"
assert_not_contains "jeton absent du journal" "$(cat "$LOG_FILE")" "JETON-FACTICE"

test_done
