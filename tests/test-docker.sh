#!/usr/bin/env bash
# tests/test-docker.sh — module docker avec des doublures (dpkg-query, getent,
# id, systemctl paramétrés par des fichiers ; run_sudo qui journalise et simule
# apt-get, groupadd, usermod et systemctl enable ; apt_add_repo qui compte ses
# appels, le helper ayant ses propres tests dans test-apt.sh) : aucune
# installation réelle, aucun réseau, aucun sudo.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"
# shellcheck source=../lib/apt.sh
source "$DOTFILES_DIR/lib/apt.sh"
# shellcheck source=../lib/module.sh
source "$DOTFILES_DIR/lib/module.sh"

mkdir -p "$TEST_TMP/bin"
export FAKE_DIR="$TEST_TMP"
export USER=u
INSTALLED="$TEST_TMP/installed"; : >"$INSTALLED"
CALLS="$TEST_TMP/calls"; : >"$CALLS"
GROUP="$TEST_TMP/group"; : >"$GROUP"                 # ligne « docker:x:986:membres », vide = groupe absent
SESSION="$TEST_TMP/session-groups"; printf 'u sudo' >"$SESSION"
ENABLED="$TEST_TMP/svc-enabled"; ACTIVE="$TEST_TMP/svc-active"   # présents = vrai
BROKEN="$TEST_TMP/svc-broken"                        # présent = le service refuse de démarrer
ENABLE_FAILS="$TEST_TMP/svc-enable-fails"            # présent = `systemctl enable --now` échoue

cat >"$TEST_TMP/bin/dpkg-query" <<'FAKE'
#!/usr/bin/env bash
grep -qx -- "${*: -1}" "$FAKE_DIR/installed" 2>/dev/null && printf 'install ok installed'
FAKE
cat >"$TEST_TMP/bin/getent" <<'FAKE'
#!/usr/bin/env bash
[ "$1" = group ] && [ -s "$FAKE_DIR/group" ] || exit 2
cat "$FAKE_DIR/group"
FAKE
cat >"$TEST_TMP/bin/id" <<'FAKE'
#!/usr/bin/env bash
case ${1:-} in
  -nG) cat "$FAKE_DIR/session-groups"; printf '\n' ;;
  -un) printf 'u\n' ;;
  *) exit 1 ;;
esac
FAKE
# systemctl : is-enabled / is-active lisent les marqueurs, sans être journalisés
# (module_check les appelle). enable passe par run_sudo, simulé plus bas.
cat >"$TEST_TMP/bin/systemctl" <<'FAKE'
#!/usr/bin/env bash
case ${1:-} in
  is-enabled) [ -e "$FAKE_DIR/svc-enabled" ] ;;
  is-active)  [ -e "$FAKE_DIR/svc-active" ] ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
# shellcheck source=../modules/41-docker.sh
source "$DOTFILES_DIR/modules/41-docker.sh"

# Doublure : journalise chaque appel et en simule l'effet sur les marqueurs.
run_sudo() {
  printf '%s\n' "$*" >>"$CALLS"
  local args=("$@") a
  [[ ${args[0]} == env ]] && args=("${args[@]:2}")
  case "${args[0]} ${args[1]:-}" in
    "apt-get install")
      for a in "${args[@]:2}"; do [[ $a == -* ]] || printf '%s\n' "$a" >>"$INSTALLED"; done
      # Comme le postinst de docker-ce : groupe créé, service activé et démarré.
      if [[ " ${args[*]} " == *" docker-ce "* ]]; then
        [[ -s $GROUP ]] || printf 'docker:x:986:\n' >"$GROUP"
        touch "$ENABLED" "$ACTIVE"
      fi ;;
    "apt-get remove")
      for a in "${args[@]:2}"; do
        [[ $a == -* ]] && continue
        grep -vx -- "$a" "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
      done ;;
    "groupadd --system") printf 'docker:x:986:\n' >"$GROUP" ;;
    "usermod -aG")
      local line; line=$(cat "$GROUP")
      if [[ $line == *: ]]; then printf '%s%s\n' "$line" "${args[3]}" >"$GROUP"
      else printf '%s,%s\n' "$line" "${args[3]}" >"$GROUP"; fi ;;
    "systemctl enable")
      # Échec de la commande elle-même : même rapport que le vrai run_sudo.
      if [[ -e $ENABLE_FAILS ]]; then
        printf '[00:00:00] $ sudo -n %s\n' "$*" >>"$LOG_FILE"
        _run_report_failure 1 "sudo -n $*"
        return 1
      fi
      [[ -e $BROKEN ]] || touch "$ENABLED" "$ACTIVE" ;;
  esac
  return 0
}
apt_add_repo() { printf 'apt_add_repo %s\n' "$*" >>"$CALLS"; }
count_calls() { grep -c -- "$1" "$CALLS" || true; }
line_of() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }
_APT_UPDATED=1

printf '%s\n' "== état initial =="
assert_fail "module_check → à faire" module_check

printf '%s\n' "== première application =="
assert_ok "module_install réussit" module_install
assert_eq "aucun paquet en conflit à retirer → aucun apt-get remove" 0 "$(count_calls 'apt-get remove')"
assert_contains "dépôt officiel déclaré" "$(cat "$CALLS")" \
  "apt_add_repo docker https://download.docker.com/linux/ubuntu/gpg https://download.docker.com/linux/ubuntu auto stable"
assert_eq "un seul apt-get install" 1 "$(count_calls 'apt-get install')"
assert_contains "les cinq paquets passés à apt" "$(grep 'apt-get install' "$CALLS")" \
  "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
assert_ok "dépôt déclaré avant l'installation" test "$(line_of apt_add_repo)" -lt "$(line_of 'apt-get install')"
assert_fail "module_check toujours à faire (utilisateur pas encore membre)" module_check
: >"$CALLS"
out=$(module_configure 2>&1); rc=$?
assert_eq "module_configure réussit" 0 "$rc"
assert_eq "groupe créé par le paquet → aucun groupadd" 0 "$(count_calls groupadd)"
assert_contains "utilisateur ajouté au groupe" "$(cat "$CALLS")" "usermod -aG docker u"
assert_eq "service démarré par le paquet → aucun systemctl enable" 0 "$(count_calls 'systemctl enable')"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== session ouverte avant l'ajout au groupe =="
assert_contains "l'écart est signalé" "$out" "ne porte pas encore le groupe docker"
assert_contains "réouverture de session dans le résumé" "$(cat "$MANUAL_STEPS_FILE")" "rouvrir la session"
assert_ok "module_check reste « déjà fait » (situation transitoire)" module_check

printf '%s\n' "== session à jour =="
: >"$MANUAL_STEPS_FILE"; printf 'u sudo docker' >"$SESSION"
assert_ok "module_configure réussit" module_configure
assert_eq "aucune étape manuelle à ce titre" "" "$(cat "$MANUAL_STEPS_FILE")"

printf '%s\n' "== réexécution =="
: >"$CALLS"
assert_ok "module_install réussit" module_install
assert_eq "aucun apt-get install" 0 "$(count_calls 'apt-get install')"
assert_ok "module_configure réussit" module_configure
assert_eq "déjà membre → aucun usermod" 0 "$(count_calls usermod)"
assert_eq "service en marche → aucun systemctl" 0 "$(count_calls systemctl)"

printf '%s\n' "== paquet Docker d'Ubuntu présent =="
: >"$INSTALLED"; : >"$CALLS"; printf 'docker.io\nrunc\n' >>"$INSTALLED"
assert_ok "module_install réussit" module_install
assert_contains "docker.io et runc retirés" "$(grep 'apt-get remove' "$CALLS")" "docker.io runc"
assert_not_contains "remove, pas purge (/var/lib/docker conservé)" "$(cat "$CALLS")" "purge"
assert_not_contains "seuls les paquets présents sont passés à apt" "$(grep 'apt-get remove' "$CALLS")" "podman-docker"
assert_ok "retrait avant le dépôt" test "$(line_of 'apt-get remove')" -lt "$(line_of apt_add_repo)"
assert_ok "retrait avant l'installation" test "$(line_of 'apt-get remove')" -lt "$(line_of 'apt-get install')"

printf '%s\n' "== groupe absent =="
: >"$GROUP"; : >"$CALLS"
assert_ok "module_configure réussit" module_configure
assert_contains "groupe créé" "$(cat "$CALLS")" "groupadd --system docker"
assert_ok "groupe créé avant l'ajout" test "$(line_of groupadd)" -lt "$(line_of usermod)"
assert_ok "utilisateur membre" _docker_user_in_group

printf '%s\n' "== appartenance par nom exact =="
printf 'docker:x:986:uu,autre\n' >"$GROUP"
assert_fail "« uu » n'est pas « u »" _docker_user_in_group
printf 'docker:x:986:autre,u\n' >"$GROUP"
assert_ok "membre en fin de liste" _docker_user_in_group

printf '%s\n' "== service arrêté =="
rm -f "$ACTIVE"; : >"$CALLS"
assert_fail "module_check → à faire" module_check
assert_ok "module_configure réussit" module_configure
assert_contains "service activé et démarré" "$(cat "$CALLS")" "systemctl enable --now docker.service containerd.service"
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== service désactivé =="
rm -f "$ENABLED"
assert_fail "module_check → à faire" module_check
assert_ok "module_configure le rétablit" module_configure
assert_ok "module_check → déjà fait" module_check

printf '%s\n' "== service impossible à démarrer =="
rm -f "$ENABLED" "$ACTIVE"; touch "$BROKEN"
out=$(module_configure 2>&1); rc=$?
assert_ok "module_configure échoue" test "$rc" -ne 0
assert_contains "le service est nommé" "$out" "docker.service"
assert_fail "module_check → à faire" module_check
rm -f "$BROKEN"
assert_ok "après correction, module_configure rétablit" module_configure

printf '%s\n' "== systemctl enable --now qui échoue =="
rm -f "$ENABLED" "$ACTIVE"; touch "$ENABLE_FAILS"
out=$(module_configure 2>&1); rc=$?
assert_ok "module_configure échoue" test "$rc" -ne 0
assert_contains "le service est nommé" "$out" "docker.service"
assert_not_contains "aucune constatation de succès" "$out" "activé et démarré"
assert_fail "module_check → à faire" module_check
rm -f "$ENABLE_FAILS"
assert_ok "après correction, module_configure rétablit" module_configure

printf '%s\n' "== module_check : chacune de ses conditions =="
assert_ok "module_check → déjà fait" module_check
grep -vx docker-compose-plugin "$INSTALLED" >"$TEST_TMP/reste"; mv "$TEST_TMP/reste" "$INSTALLED"
assert_fail "un paquet absent → à faire" module_check
printf 'docker-compose-plugin\n' >>"$INSTALLED"
printf 'docker:x:986:autre\n' >"$GROUP"
assert_fail "utilisateur hors du groupe → à faire" module_check
printf 'docker:x:986:autre,u\n' >"$GROUP"
rm -f "$ACTIVE"
assert_fail "service arrêté → à faire" module_check
touch "$ACTIVE"; rm -f "$ENABLED"
assert_fail "service désactivé → à faire" module_check
touch "$ENABLED"
assert_ok "module_check → déjà fait" module_check

test_done
