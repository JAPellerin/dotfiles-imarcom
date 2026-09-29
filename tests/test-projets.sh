#!/usr/bin/env bash
# tests/test-projets.sh — module projets avec de vrais dépôts git (dépôts nus
# locaux en file:// comme dépôts distants) et des doublures : op (session,
# lectures par référence, item get/create/edit), curl (clés de Bitbucket), mkcert
# (-CAROOT, -install), dpkg-query et apt-get (paquets dans un fichier), sudo
# factice (run_sudo et run restent les vrais : le </dev/null de run s'applique).
# Fonctions du module appelées par module_call, comme le fait le runner.
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
fake_sudo
export HOME="$TEST_TMP/home" FAKE_DIR="$TEST_TMP"
# lib/op.sh a calculé le socket de l'agent avec le vrai HOME : celui du test.
export OP_AGENT_SOCK="$HOME/.1password/agent.sock"
mkdir -p "$HOME" "$TEST_TMP/ca" "$TEST_TMP/remotes"
export PROJETS_HOSTS_FILE="$TEST_TMP/etc-hosts" PROJETS_CA_DIR="$TEST_TMP/ca"
export PROJETS_URL_RE='^(file:///.+|git@[A-Za-z0-9.-]+:[A-Za-z0-9._/~-]+)$'
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL="$TEST_TMP/gitconfig"; printf '[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n' >"$GIT_CONFIG_GLOBAL"
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
MOD="$DOTFILES_DIR/modules/80-projets.sh"
R="$TEST_TMP/remotes"
export OPD="$TEST_TMP/op"; mkdir -p "$OPD"
PRIV_MARK="CLE-PRIVEE-LEGACY-FACTICE-7"

# Clés d'hôte de Bitbucket factices mais valides (ssh-keygen -F les lit).
ssh-keygen -q -t ed25519 -N '' -f "$TEST_TMP/bbkey" -C x >/dev/null
printf 'bitbucket.org %s\n' "$(cut -d' ' -f1-2 "$TEST_TMP/bbkey.pub")" >"$TEST_TMP/bb-keys"

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/apt-get" <<'FAKE'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$FAKE_DIR/calls"
[[ $1 == install ]] || exit 0
shift; for a in "$@"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$FAKE_DIR/installed"; done
FAKE
cat >"$TEST_TMP/bin/curl" <<'FAKE'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >>"$FAKE_DIR/calls"
[[ -e $FAKE_DIR/curl-refuse ]] && exit 22
[[ ${*: -1} == https://bitbucket.org/site/ssh ]] && cat "$FAKE_DIR/bb-keys"
FAKE
cat >"$TEST_TMP/bin/mkcert" <<'FAKE'
#!/usr/bin/env bash
case $1 in
  -CAROOT) printf '%s\n' "$FAKE_DIR/caroot" ;;
  -install) printf 'mkcert -install\n' >>"$FAKE_DIR/calls"
            mkdir -p "$FAKE_DIR/caroot"; : >"$FAKE_DIR/caroot/rootCA.pem"
            : >"$PROJETS_CA_DIR/mkcert_development_CA_123.crt" ;;
esac
FAKE
# op : session si $FAKE_DIR/session ; lectures depuis $OPD/<nom> ; item get/create/edit.
cat >"$TEST_TMP/bin/op" <<'FAKE'
#!/usr/bin/env bash
notfound() { echo "[ERROR] \"$1\" isn't an item in the \"$2\" vault" >&2; exit 1; }
nofield() { echo "[ERROR] item '$1' does not have a field '$2'" >&2; exit 1; }
case $1 in
  whoami) [[ -f $FAKE_DIR/session ]] ;;
  read) printf 'op read %s\n' "${*: -1}" >>"$FAKE_DIR/calls"
        case ${*: -1} in
          op://Imarcom/Projets/notesPlain) [[ -f $OPD/item ]] || notfound Projets Imarcom; cat "$OPD/tree" 2>/dev/null ;;
          op://Imarcom/Projets/hosts) [[ -f $OPD/item ]] || notfound Projets Imarcom
                                     [[ -f $OPD/hosts ]] || nofield Imarcom/Projets hosts; cat "$OPD/hosts" ;;
          "op://Private/Legacy SSH/public key") [[ -f $OPD/legacy-pub ]] || notfound "Legacy SSH" Private; cat "$OPD/legacy-pub" ;;
          "op://Private/Legacy SSH/notesPlain") [[ -f $OPD/legacy-pub ]] || notfound "Legacy SSH" Private; cat "$OPD/legacy-notes" 2>/dev/null ;;
          "op://Private/Legacy SSH/private key?ssh-format=openssh") [[ -f $OPD/legacy-pub ]] || notfound "Legacy SSH" Private; cat "$OPD/legacy-priv" ;;
          *) echo "[ERROR] introuvable" >&2; exit 1 ;;
        esac ;;
  item)
    case $2 in
      get) [[ -f $OPD/item ]] ;;
      create|edit)
        printf 'op item %s\n' "$2" >>"$FAKE_DIR/calls"
        for a in "$@"; do [[ $a == notesPlain=* ]] && printf '%s' "${a#notesPlain=}" >"$OPD/tree"; done
        touch "$OPD/item" ;;
    esac ;;
esac
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
export INSTALLED CALLS TEST_TMP
_APT_UPDATED=1; export _APT_UPDATED
mcall() { module_call "$MOD" "$1"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }

# make_remote <nom> [setup] : dépôt nu $R/<nom>.git avec un commit (Makefile
# avec cible setup: si demandé).
make_remote() {
  local w="$TEST_TMP/work-$1"
  git init -q "$w"
  printf 'lisez-moi\n' >"$w/README"
  [[ ${2:-} == setup ]] && printf 'setup:\n\t@echo ok\n' >"$w/Makefile"
  git -C "$w" add -A && git -C "$w" commit -qm init
  git clone -q --bare "$w" "$R/$1.git"
}
# advance_remote <nom> : un commit de plus sur le dépôt distant.
advance_remote() {
  local w="$TEST_TMP/adv-$1"
  rm -rf "$w"; git clone -q "$R/$1.git" "$w"
  printf 'suite %s\n' "$RANDOM" >>"$w/README"
  git -C "$w" commit -qam suite && git -C "$w" push -q origin HEAD
}
url() { printf 'file://%s/%s.git' "$R" "$1"; }
make_remote app setup; make_remote doc; make_remote vieux; make_remote nouveau

# État 1Password : arbre (avec lignes refusées), domaines, clé legacy.
write_tree() {
  printf 'projets/client/app\t%s\nprojets/client/doc\t%s\nprojets/client/legacy/vieux\t%s\n' \
    "$(url app)" "$(url doc)" "$(url vieux)" >"$OPD/tree"
  printf '# commentaire\n\nprojets/../evade\t%s\n/abs/chemin\t%s\nailleurs/x\t%s\nprojets/client/mauvais\tftp://x/y\n' \
    "$(url app)" "$(url app)" "$(url app)" >>"$OPD/tree"
}
touch "$OPD/item"; write_tree
printf 'exemple.local.test, storybook.exemple.local.test\nmauvais_domaine\n' >"$OPD/hosts"
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeLegacyKey legacy\n' >"$OPD/legacy-pub"
printf 'Host hote-legacy\n  HostName legacy.example.invalid\n  IdentityFile ~/.ssh/id_ed25519_legacy\n  IdentitiesOnly yes\n' >"$OPD/legacy-notes"
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\n%s\n-----END OPENSSH PRIVATE KEY-----\n' "$PRIV_MARK" >"$OPD/legacy-priv"
printf '127.0.0.1\tlocalhost\n' >"$PROJETS_HOSTS_FILE"

printf '%s\n' "== métadonnées =="
meta() { bash -c 'source "$1"; printf "%s" "${!2:-}"' _ "$MOD" "$1"; }
assert_contains "dépend de git" "$(meta MODULE_DEPS)" "git"
assert_contains "dépend de 1password" "$(meta MODULE_DEPS)" "1password"
assert_eq "module non graphique" "" "$(meta MODULE_NEEDS_GUI)"
assert_ok "description renseignée" test -n "$(meta MODULE_DESC)"
assert_fail "aucun nom propre aux projets dans le module (hôte d'exemple)" grep -qi 'exemple.local' "$MOD"

printf '%s\n' "== sans session 1Password =="
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape : relever les projets" "$(cat "$MANUAL_STEPS_FILE")" "setup.sh --snapshot-projets"
assert_contains "étape : clé legacy" "$(cat "$MANUAL_STEPS_FILE")" "Legacy SSH"
assert_fail "aucun clone" test -d "$HOME/projets"
assert_eq "mkcert -install appelé (sans 1Password)" 1 "$(count_calls 'mkcert -install')"
assert_eq "aucune lecture dans 1Password" 0 "$(count_calls 'op read')"
assert_fail "module_check → à faire" mcall module_check

printf '%s\n' "== premier passage =="
touch "$TEST_TMP/session"; : >"$MANUAL_STEPS_FILE"; : >"$CALLS"; : >"$LOG_FILE"
mkdir -p "$HOME/.ssh"; printf 'Host vm\n  HostName 10.0.0.1\n' >"$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"
assert_ok "module_install réussit" mcall module_install
assert_contains "mkcert et libnss3-tools installés" "$(cat "$INSTALLED")" $'mkcert\nlibnss3-tools'
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
for p in app doc legacy/vieux; do
  assert_ok "cloné : $p" test -d "$HOME/projets/client/$p/.git"
done
assert_contains "étape make setup pour app" "$(cat "$MANUAL_STEPS_FILE")" "cd ~/projets/client/app && make setup"
assert_not_contains "aucune étape make setup pour doc" "$(cat "$MANUAL_STEPS_FILE")" "client/doc"
assert_contains "ligne .. refusée et nommée" "$out" "projets/../evade"
assert_contains "chemin absolu refusé" "$out" "/abs/chemin"
assert_contains "hors de ~/projets refusé" "$out" "ailleurs/x"
assert_contains "URL invalide refusée" "$out" "ftp://x/y"
assert_fail "rien écrit hors de ~/projets" test -e "$HOME/evade"
assert_ok "bitbucket.org connu" ssh-keygen -F bitbucket.org -f "$HOME/.ssh/known_hosts"
assert_ok "autorité mkcert posée" test -f "$TEST_TMP/caroot/rootCA.pem"
assert_ok "domaine ajouté" grep -qxP '127\.0\.0\.1\texemple\.local\.test' "$PROJETS_HOSTS_FILE"
assert_ok "second domaine ajouté (virgule)" grep -qxP '127\.0\.0\.1\tstorybook\.exemple\.local\.test' "$PROJETS_HOSTS_FILE"
assert_ok "ligne existante gardée" grep -qxP '127\.0\.0\.1\tlocalhost' "$PROJETS_HOSTS_FILE"
assert_contains "domaine invalide refusé" "$out" "mauvais_domaine"
assert_fail "domaine invalide non écrit" grep -q mauvais_domaine "$PROJETS_HOSTS_FILE"
assert_eq "clé publique legacy" "$(cat "$OPD/legacy-pub")" "$(cat "$HOME/.ssh/id_ed25519_legacy.pub")"
assert_eq "clé privée legacy en 0600 (sans agent)" 600 "$(stat -c %a "$HOME/.ssh/id_ed25519_legacy")"
assert_contains "clé privée legacy écrite" "$(cat "$HOME/.ssh/id_ed25519_legacy")" "$PRIV_MARK"
assert_not_contains "clé privée absente de la sortie" "$out" "$PRIV_MARK"
assert_not_contains "clé privée absente du journal" "$(cat "$LOG_FILE")" "$PRIV_MARK"
assert_eq "bloc Host legacy écrit" "$(cat "$OPD/legacy-notes")" "$(cat "$HOME/.ssh/config.d/projets.conf")"
assert_eq "bloc en 0600" 600 "$(stat -c %a "$HOME/.ssh/config.d/projets.conf")"
assert_eq "Include en tête de ~/.ssh/config" "Include config.d/*.conf" "$(head -n1 "$HOME/.ssh/config")"
assert_contains "blocs existants gardés" "$(cat "$HOME/.ssh/config")" $'Host vm\n  HostName 10.0.0.1'
assert_eq "mode de ~/.ssh/config gardé" 600 "$(stat -c %a "$HOME/.ssh/config")"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== relance : rien de refait =="
printf 'travail local\n' >>"$HOME/projets/client/app/README"
: >"$MANUAL_STEPS_FILE"; : >"$CALLS"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "mkcert -install pas rappelé" 0 "$(count_calls 'mkcert -install')"
assert_eq "Include une seule fois" 1 "$(grep -cxF 'Include config.d/*.conf' "$HOME/.ssh/config")"
assert_eq "domaines sans doublon" 1 "$(grep -cP '\texemple\.local\.test$' "$PROJETS_HOSTS_FILE")"
assert_contains "clone existant intact" "$(cat "$HOME/projets/client/app/README")" "travail local"
assert_eq "aucune étape make setup" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== domaines : autre adresse, ligne commentée, champ absent =="
printf '10.1.2.3 deja.local.test\n# 127.0.0.1 commente.local.test\n' >>"$PROJETS_HOSTS_FILE"
printf 'deja.local.test commente.local.test' >"$OPD/hosts"
assert_ok "module_configure réussit" mcall module_configure
assert_eq "domaine déjà nommé (autre adresse) : rien ajouté" 1 "$(grep -c 'deja.local.test' "$PROJETS_HOSTS_FILE")"
assert_ok "domaine seulement commenté : ajouté" grep -qxP '127\.0\.0\.1\tcommente\.local\.test' "$PROJETS_HOSTS_FILE"
rm -f "$OPD/hosts"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "champ hosts absent : pas d'erreur" 0 "$rc"
assert_not_contains "champ absent : aucun avertissement rouge" "$out" "✖"

printf '%s\n' "== dossier étranger =="
rm -rf "$HOME/projets/client/doc"; mkdir -p "$HOME/projets/client/doc"; printf 'x\n' >"$HOME/projets/client/doc/note"
rm -rf "$HOME/projets/client/legacy"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure échoue" 1 "$rc"
assert_contains "chemin nommé" "$out" "projets/client/doc"
assert_ok "dossier étranger intact" test -f "$HOME/projets/client/doc/note"
assert_ok "les autres clonés quand même" test -d "$HOME/projets/client/legacy/vieux/.git"
rm -rf "$HOME/projets/client/doc"; mcall module_configure >/dev/null 2>&1

printf '%s\n' "== agent 1Password =="
printf '1password\n' >>"$INSTALLED"
sock_of() { _projets_env; printf '%s' "${SSH_AUTH_SOCK:-}"; }
mkdir -p "$HOME/.1password"
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$HOME/.1password/agent.sock"
assert_eq "SSH_AUTH_SOCK exporté vers l'agent" "$HOME/.1password/agent.sock" "$(SSH_AUTH_SOCK='' module_call "$MOD" sock_of)"
rm -f "$HOME/.ssh/id_ed25519_legacy"
assert_ok "module_configure réussit" mcall module_configure
assert_fail "aucune clé privée écrite avec l'agent" test -e "$HOME/.ssh/id_ed25519_legacy"
assert_ok "module_check → déjà fait (agent)" mcall module_check
grep -vx 1password "$INSTALLED" >"$TEST_TMP/i2"; mv "$TEST_TMP/i2" "$INSTALLED"; rm -f "$HOME/.1password/agent.sock"
assert_fail "sans agent ni clé privée → à faire" mcall module_check
mcall module_configure >/dev/null 2>&1

printf '%s\n' "== clé legacy absente de 1Password =="
mv "$OPD/legacy-pub" "$OPD/legacy-pub.bak"; : >"$MANUAL_STEPS_FILE"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_contains "étape d'import de la clé" "$(cat "$MANUAL_STEPS_FILE")" "Legacy SSH"
mv "$OPD/legacy-pub.bak" "$OPD/legacy-pub"

printf '%s\n' "== ~/.ssh/config absent =="
rm -f "$HOME/.ssh/config"
out=$(mcall module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_eq ".ssh/config créé avec l'inclusion seule" "Include config.d/*.conf" "$(cat "$HOME/.ssh/config")"
assert_eq ".ssh/config en 0600" 600 "$(stat -c %a "$HOME/.ssh/config")"

printf '%s\n' "== module_check : chacune de ses conditions =="
assert_ok "tout est en place" mcall module_check
mv "$HOME/.ssh/config.d/projets.conf" "$TEST_TMP/conf.bak"
assert_fail "bloc legacy retiré → à faire" mcall module_check
mv "$TEST_TMP/conf.bak" "$HOME/.ssh/config.d/projets.conf"
sed -i '/^Include config.d/d' "$HOME/.ssh/config"
assert_fail "Include retiré → à faire" mcall module_check
mcall module_configure >/dev/null 2>&1
mv "$HOME/.ssh/known_hosts" "$TEST_TMP/kh.bak"
assert_fail "bitbucket.org inconnu → à faire" mcall module_check
mv "$TEST_TMP/kh.bak" "$HOME/.ssh/known_hosts"
rm -f "$PROJETS_CA_DIR"/*.crt
assert_fail "autorité hors du magasin → à faire" mcall module_check
mcall module_configure >/dev/null 2>&1
mv "$HOME/projets" "$TEST_TMP/projets.bak"
assert_fail "aucun dépôt → à faire" mcall module_check
mv "$TEST_TMP/projets.bak" "$HOME/projets"
assert_ok "module_check → déjà fait" mcall module_check

printf '%s\n' "== relevé =="
# Dépôt imbriqué, dépôt dans node_modules, dépôt sans origin.
git init -q "$HOME/projets/client/app/vendu"; git -C "$HOME/projets/client/app/vendu" remote add origin "$(url nouveau)"
git init -q "$HOME/projets/client/app/node_modules/pkg"; git -C "$HOME/projets/client/app/node_modules/pkg" remote add origin "$(url nouveau)"
git init -q "$HOME/projets/client/sans-origin"
git clone -q "$(url doc)" "$HOME/projets/client/doc" 2>/dev/null || true
rm -f "$OPD/item" "$OPD/tree"; : >"$CALLS"
out=$(mcall projets_snapshot 2>&1); rc=$?
assert_eq "relevé réussit" 0 "$rc"
assert_eq "arbre trié, sans dépôt imbriqué ni node_modules ni sans origin" \
  "$(printf 'projets/client/app\t%s\nprojets/client/doc\t%s\nprojets/client/legacy/vieux\t%s' "$(url app)" "$(url doc)" "$(url vieux)")" "$(cat "$OPD/tree")"
assert_eq "élément absent → créé" 1 "$(count_calls 'op item create')"
assert_contains "dépôt sans origin signalé" "$out" "projets/client/sans-origin"
assert_contains "nombre de dépôts affiché" "$out" "3 dépôt(s)"
: >"$CALLS"
out=$(mcall projets_snapshot 2>&1); rc=$?
assert_eq "relance réussit" 0 "$rc"
assert_contains "arbre inchangé" "$out" "Arbre inchangé"
assert_eq "aucune écriture" 0 "$(count_calls 'op item')"
printf 'autre\n' >"$OPD/tree"; : >"$CALLS"
mcall projets_snapshot >/dev/null 2>&1
assert_eq "arbre changé → élément édité" 1 "$(count_calls 'op item edit')"
rm -rf "$HOME/projets/client/sans-origin" "$HOME/projets/client/app/vendu" "$HOME/projets/client/app/node_modules"

printf '%s\n' "== mise à jour =="
A="$HOME/projets/client/app" D="$HOME/projets/client/doc" V="$HOME/projets/client/legacy/vieux"
git -C "$A" checkout -q -- README
advance_remote app; advance_remote doc; advance_remote vieux
printf 'égaré\n' >"$A/non-suivi.txt"                 # fichier non suivi : n'empêche pas l'avance
printf 'modif\n' >>"$D/README"                        # modification suivie : laissé
git -C "$V" checkout -q --detach                      # tête détachée : sans branche suivie
write_tree; printf 'projets/client/nouveau\t%s\n' "$(url nouveau)" >>"$OPD/tree"
printf 'exemple.local.test' >"$OPD/hosts"
out=$(mcall projets_pull 2>&1); rc=$?
assert_eq "mise à jour réussie" 0 "$rc"
assert_eq "app avancé (fichier non suivi présent)" "$(git -C "$R/app.git" rev-parse main)" "$(git -C "$A" rev-parse HEAD)"
assert_contains "doc laissé : modifications en cours" "$out" "projets/client/doc : modifications en cours"
assert_contains "doc : modification gardée" "$(cat "$D/README")" "modif"
assert_contains "vieux laissé : sans branche suivie" "$out" "projets/client/legacy/vieux : sans branche suivie"
assert_ok "nouveau cloné" test -d "$HOME/projets/client/nouveau/.git"
assert_contains "bilan" "$out" "1 mis à jour, 0 déjà à jour, 1 cloné(s), 2 laissé(s) de côté, 0 échec(s)"
git -C "$D" checkout -q -- README; git -C "$V" checkout -q main
printf 'local\n' >"$D/local.txt"; git -C "$D" add local.txt; git -C "$D" commit -qm local
out=$(mcall projets_pull 2>&1); rc=$?
assert_contains "doc divergé : laissé" "$out" "projets/client/doc : divergé"
assert_contains "vieux avancé" "$out" "Mis à jour : projets/client/legacy/vieux"
git -C "$D" reset -q --hard origin/main; printf 'local\n' >"$D/l2.txt"; git -C "$D" add l2.txt; git -C "$D" commit -qm l2
out=$(mcall projets_pull 2>&1)
assert_contains "doc en avance : laissé" "$out" "projets/client/doc : en avance (1 commit(s) non poussé(s))"
printf 'projets/client/absent\t%s\n' "file://$R/absent.git" >>"$OPD/tree"
out=$(mcall projets_pull 2>&1); rc=$?
assert_eq "clonage en échec → code 1" 1 "$rc"
assert_contains "échec nommé" "$out" "projets/client/absent"

test_done
