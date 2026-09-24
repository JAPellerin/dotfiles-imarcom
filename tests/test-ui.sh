#!/usr/bin/env bash
# tests/test-ui.sh — lib/ui.sh : largeur de la ligne animée du spinner (troncature
# du titre à la largeur du terminal). Les wrappers gum se voient dans demo-ui.sh.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"

printf '%s\n' "== _ui_fit =="
assert_eq "titre court laissé tel quel" "Installation apt : jq" "$(_ui_fit "Installation apt : jq" 40)"
assert_eq "titre de la largeur exacte laissé tel quel" "abcde" "$(_ui_fit "abcde" 5)"
assert_eq "titre trop long tronqué avec « … »" "abcd…" "$(_ui_fit "abcdefgh" 5)"
long="Installation apt : docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
fit=$(_ui_fit "$long" 77)
assert_eq "le titre Docker tient en 77 caractères" 77 "${#fit}"
assert_eq "largeur nulle ou négative → un caractère" "…" "$(_ui_fit "abc" 0)"
assert_eq "caractères accentués comptés comme un" "éé…" "$(_ui_fit "ééééé" 3)"

printf '%s\n' "== _ui_columns =="
assert_eq "sans terminal → 80" 80 "$(_ui_columns 2>/dev/null)"
if command -v script >/dev/null 2>&1; then
  out=$(script -qec "stty cols 50 rows 20; bash -c 'LOG_FILE=$LOG_FILE; source lib/core.sh; source lib/ui.sh; _ui_columns'" /dev/null </dev/null 2>/dev/null | tr -d '\r')
  assert_eq "terminal de 50 colonnes → 50" 50 "${out##*$'\n'}"
fi

printf '%s\n' "== spinner interrompu (Ctrl-C) =="
# Sous un pseudo-terminal (le spinner ne s'anime que si stderr en est un) : un
# sous-shell au premier plan s'envoie SIGINT pendant ui_wait, comme un module
# sous Ctrl-C. L'animation tourne en arrière-plan, où bash ignore SIGINT : elle
# ne doit pas survivre à son lanceur (orpheline, elle dessinait sans fin dans
# le terminal — vu en VM le 24 sept 2026). Orphelin = processus de la session
# dont le parent n'y est plus ; ceux qui restent sont tués pour ne pas bloquer script.
if command -v script >/dev/null 2>&1; then
  cat >"$TEST_TMP/spinner.sh" <<INNER
LOG_FILE='$LOG_FILE'
source '$DOTFILES_DIR/lib/core.sh'; source '$DOTFILES_DIR/lib/ui.sh'
probe() { printf x >>'$TEST_TMP/calls'; [[ \$(wc -c <'$TEST_TMP/calls') -ge 3 ]] && kill -INT "\$BASHPID"; return 1; }
( cleanup_scope; ui_wait "Attente" 30 0.1 probe ); echo "RC=\$?"
sleep 0.5
sid=\$(ps -o sid= -p \$\$ | tr -d ' ')
orphans=\$(ps -o pid=,ppid= -s "\$sid" | awk -v me=\$\$ '{pid[\$1]=1; pp[\$1]=\$2} END {for (p in pid) if (p != me && !(pp[p] in pid)) print p}')
echo "ORPHELINS=\$(printf '%s' "\$orphans" | grep -c .)"
[[ -n \$orphans ]] && kill \$orphans 2>/dev/null
exit 0
INNER
  out=$(timeout 20 script -qec "bash $TEST_TMP/spinner.sh" /dev/null </dev/null 2>/dev/null | tr -d '\r')
  assert_contains "le sous-shell est interrompu (code 130)" "$out" "RC=130"
  assert_contains "aucune animation ne survit à Ctrl-C" "$out" "ORPHELINS=0"
fi

test_done
