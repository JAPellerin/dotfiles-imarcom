#!/usr/bin/env bash
# tests/test-refs.sh — chaque chemin `openspec/…` cité dans le code existe dans
# le dépôt. Un renvoi vers un change actif (`openspec/changes/<nom>/`) est
# accepté tant que le change l'est ; archiver le change sans corriger ses
# renvois fait échouer ce test. Règle des renvois : CLAUDE.md, section OpenSpec.
# tests/ n'est pas examiné : ses fichiers citent des chemins à titre d'exemple.
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

# _refs : chemins cités, un par ligne, ponctuation finale retirée (« spec.md. »).
_refs() {
  (cd -- "$DOTFILES_DIR" && grep -rhoE 'openspec/[^[:space:]`"'"'"')]+' \
    lib modules config setup.sh bootstrap.sh) \
    | sed -E 's/[.,;:]+$//' | sort -u
}

# _expand <chemin> : développe une forme groupée `préfixe{a,b}suffixe`.
_expand() {
  local ref=$1 pre alts post alt
  if [[ $ref =~ ^([^{]*)\{([^}]*)\}(.*)$ ]]; then
    pre=${BASH_REMATCH[1]} alts=${BASH_REMATCH[2]} post=${BASH_REMATCH[3]}
    IFS=',' read -ra parts <<<"$alts"
    for alt in "${parts[@]}"; do printf '%s%s%s\n' "$pre" "$alt" "$post"; done
  else
    printf '%s\n' "$ref"
  fi
}

printf '%s\n' "== développement des formes groupées =="
assert_eq "{a,b} développé" $'x/{a/s.md,b.md}\nx/a/s.md\nx/b.md' \
  "$(printf 'x/{a/s.md,b.md}\n'; _expand 'x/{a/s.md,b.md}')"
assert_eq "chemin simple inchangé" "openspec/specs/x/spec.md" "$(_expand openspec/specs/x/spec.md)"

printf '%s\n' "== renvois du code =="
refs=$(_refs)
assert_ok "au moins un renvoi relevé" test -n "$refs"
while IFS= read -r ref; do
  while IFS= read -r path; do
    assert_ok "existe : $path" test -e "$DOTFILES_DIR/$path"
  done < <(_expand "$ref")
done <<<"$refs"

test_done
