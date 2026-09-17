#!/usr/bin/env bash
# tests/run-all.sh — enchaîne tous les tests automatisés (tests/test-*.sh) et
# s'arrête en échec si l'un d'eux échoue. demo-ui.sh (interactif) est exclu.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1
failed=0
for t in tests/test-*.sh; do
  printf '\n### %s\n' "$t"
  bash "$t" || failed=1
done
printf '\n'
if (( failed )); then echo "Au moins un test a échoué." >&2; exit 1; fi
echo "Tous les tests passent."
