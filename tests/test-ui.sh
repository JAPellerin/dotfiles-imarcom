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

test_done
