#!/usr/bin/env bash
# tests/test-git.sh — module git avec un HOME isolé et des doublures (dpkg-query
# paramétrable, op, gh, curl) ; jq et ssh-keygen réels. Aucun réseau.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/op.sh
source "$DOTFILES_DIR/lib/op.sh"
# shellcheck source=../lib/files.sh
source "$DOTFILES_DIR/lib/files.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

for tool in jq ssh-keygen; do
  command -v "$tool" >/dev/null 2>&1 || { printf '%s absent : test sauté.\n' "$tool"; exit 0; }
done

# --- HOME isolé et doublures -----------------------------------------------------
export HOME="$TEST_TMP/home"
mkdir -p "$HOME" "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
# Vraie paire de clés (jetable) pour que ssh-keygen -l accepte la clé publique.
ssh-keygen -q -t ed25519 -N '' -C test -f "$TEST_TMP/k" >/dev/null
# dpkg-query : installé si le paquet figure dans FAKE_INSTALLED (fichier, un par ligne).
printf 'git-delta\ngh\n' >"$TEST_TMP/installed"
cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
pkg=${*: -1}
grep -qx "$pkg" "$FAKE_DIR/installed" && printf 'install ok installed'
FAKE
# op : session active si $FAKE_DIR/session existe ; read sert la fausse clé et compte les lectures.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
printf 'op %s\n' "$*" >>"$FAKE_DIR/calls"
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read)
    case ${*: -1} in
      "op://Private/GitHub SSH Key/private key?ssh-format=openssh") cat "$FAKE_DIR/k" ;;
      "op://Private/GitHub SSH Key/public key") cat "$FAKE_DIR/k.pub" ;;
      *) echo "[ERROR] référence inattendue : ${*: -1}" >&2; exit 1 ;;
    esac ;;
esac
FAKE
# gh : auth status / auth token selon un marqueur ; auth login le pose.
cat >"$TEST_TMP/bin/gh" <<'FAKE'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >>"$FAKE_DIR/calls"
case "$1 $2" in
  "auth status"|"auth token") [[ -f $FAKE_DIR/gh-logged ]] ;;
  "auth login") touch "$FAKE_DIR/gh-logged" ;;
  "api user") echo "tester" ;;
  *) exit 0 ;;
esac
FAKE
# curl : réponse factice de api.github.com/meta.
cat >"$TEST_TMP/bin/curl" <<'FAKE'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >>"$FAKE_DIR/calls"
[[ -f $FAKE_DIR/offline ]] && { echo "curl: (6) Could not resolve host" >&2; exit 6; }
printf '{"ssh_keys":["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl","ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="]}\n'
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
# shellcheck source=../modules/30-git.sh
source "$DOTFILES_DIR/modules/30-git.sh"
n_op_read() { grep -c '^op read' "$CALLS"; }
reset_calls() { : >"$CALLS"; }

printf '%s\n' "== état initial =="
assert_fail "module_check → à faire" module_check

printf '%s\n' "== avec l'application 1Password : aucune clé écrite =="
printf 'git-delta\ngh\n1password\n' >"$TEST_TMP/installed"
out=$(module_configure 2>&1); rc=$?
assert_eq "réussit" 0 "$rc"
assert_ok ".gitconfig lié" config_linked config/git/gitconfig "$HOME/.gitconfig"
assert_contains "agent 1Password annoncé" "$out" "agent 1Password"
assert_fail "aucun fichier de clé privée" test -e "$HOME/.ssh/id_ed25519"
assert_eq "aucune lecture op" 0 "$(n_op_read)"
assert_ok "github.com dans known_hosts" ssh-keygen -F github.com -f "$HOME/.ssh/known_hosts"
assert_eq "known_hosts : 2 clés GitHub" 2 "$(grep -c '^github.com ' "$HOME/.ssh/known_hosts")"
assert_eq "known_hosts en 0600" 600 "$(stat -c %a "$HOME/.ssh/known_hosts")"
assert_eq ".ssh en 0700" 700 "$(stat -c %a "$HOME/.ssh")"
assert_eq "gh auth login lancé une fois" 1 "$(grep -c '^gh auth login' "$CALLS")"
assert_contains "gh auth login en SSH, web, sans envoi de clé" "$(cat "$CALLS")" "gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== réexécution : idempotence =="
reset_calls
out=$(module_configure 2>&1); rc=$?
assert_eq "réussit" 0 "$rc"
assert_eq "known_hosts : toujours 2 clés" 2 "$(grep -c '^github.com ' "$HOME/.ssh/known_hosts")"
assert_contains "hôte déjà connu signalé" "$out" "déjà dans"
assert_eq "plus de gh auth login" 0 "$(grep -c '^gh auth login' "$CALLS")"
assert_contains "gh déjà connecté" "$out" "gh déjà connecté (tester)"

printf '%s\n' "== sans application, clé absente, session op active =="
printf 'git-delta\ngh\n' >"$TEST_TMP/installed"
touch "$TEST_TMP/session"
assert_fail "module_check → à faire (clé privée attendue sans agent)" module_check
reset_calls
out=$(module_configure 2>&1); rc=$?
assert_eq "réussit" 0 "$rc"
assert_file "clé privée écrite" "$HOME/.ssh/id_ed25519"
assert_eq "clé privée en 0600" 600 "$(stat -c %a "$HOME/.ssh/id_ed25519")"
assert_eq "clé publique en 0644" 644 "$(stat -c %a "$HOME/.ssh/id_ed25519.pub")"
assert_eq "clé privée = valeur lue dans 1Password" "$(cat "$TEST_TMP/k")" "$(cat "$HOME/.ssh/id_ed25519")"
assert_ok "clé publique valide (ssh-keygen -l)" ssh-keygen -l -f "$HOME/.ssh/id_ed25519.pub"
assert_contains "empreinte affichée" "$out" "SHA256:"
assert_eq "deux lectures op (privée, publique)" 2 "$(n_op_read)"
assert_contains "référence privée avec ssh-format=openssh" "$(cat "$CALLS")" "private key?ssh-format=openssh"
assert_not_contains "la clé privée n'est pas dans le journal" "$(cat "$LOG_FILE")" "PRIVATE KEY"
assert_not_contains "la clé privée n'est pas à l'écran" "$out" "PRIVATE KEY"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== sans application, clé présente : rien n'est lu =="
reset_calls
printf 'ma-cle\n' >"$HOME/.ssh/id_ed25519"
out=$(module_configure 2>&1); rc=$?
assert_eq "réussit" 0 "$rc"
assert_eq "aucune lecture op" 0 "$(n_op_read)"
assert_eq "la clé existante est intacte" "ma-cle" "$(cat "$HOME/.ssh/id_ed25519")"
assert_contains "clé présente signalée" "$out" "laissée intacte"

printf '%s\n' "== sans session 1Password =="
rm -f "$TEST_TMP/session" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub"
out=$(module_configure 2>&1); rc=$?
assert_eq "échoue" 1 "$rc"
assert_contains "message d'op_read" "$out" "setup.sh 1password"
assert_fail "aucune clé écrite" test -e "$HOME/.ssh/id_ed25519"

printf '%s\n' "== api.github.com injoignable =="
touch "$TEST_TMP/session" "$TEST_TMP/offline"
out=$(module_configure 2>&1); rc=$?
assert_eq "échoue" 1 "$rc"
assert_contains "erreur nommant la source" "$out" "api.github.com/meta"
assert_not_contains "l'erreur de curl n'est pas à l'écran" "$out" "Could not resolve host"
assert_contains "l'erreur de curl est au journal" "$(cat "$LOG_FILE")" "Could not resolve host"
rm -f "$TEST_TMP/offline"

printf '%s\n' "== module_check sans réseau (gh auth token) =="
module_configure >/dev/null 2>&1
reset_calls
module_check; rc=$?
assert_eq "déjà fait" 0 "$rc"
assert_eq "module_check n'appelle que gh auth token (pas status ni curl)" "gh auth token" "$(grep -E '^(gh|curl)' "$CALLS" | sort -u | tr '\n' ' ' | sed 's/ $//')"
rm -f "$TEST_TMP/gh-logged"
assert_fail "jeton gh absent → à faire" module_check

test_done
