## 1. Garde-fou d'abord

- [x] 1.1 `tests/test-refs.sh` selon D3 : relève les chemins `openspec/…` cités dans `lib/`, `modules/`, `config/`, `setup.sh`, `bootstrap.sh` (formes `{a,b}` développées) et vérifie que chacun existe ; vérifier qu'il **échoue** aujourd'hui en listant les 13 renvois morts, et `shellcheck tests/test-refs.sh` propre

## 2. Renvois corrigés

- [x] 2.1 Les 13 renvois selon D1 — spec → `openspec/specs/<capacité>/spec.md`, design → `openspec/changes/archive/<date>-<nom>/design.md`, numéros de décision conservés — dans `lib/apt.sh`, `lib/files.sh`, `lib/groups.sh`, `config/cli-tools/commonrc.sh`, `modules/21-terminal.sh`, `22-cli-tools.sh`, `25-navigateur.sh`, `30-git.sh`, `40-node.sh`, `41-docker.sh`, `42-dev-tools.sh`, `51-vscode.sh`, `52-claude-desktop.sh` ; vérifier `bash tests/test-refs.sh` vert, `git diff` limité à des lignes de commentaire, et `grep -rn "openspec/changes/[a-z]" lib modules config | grep -v archive` vide
- [x] 2.2 `CLAUDE.md`, section OpenSpec : règle de D1 et D2 (renvoi à la spec principale ; renvoi au design d'un change actif corrigé à son archivage, `tests/test-refs.sh` le vérifie) ; vérifier la relecture

## 3. Vérification d'ensemble

- [x] 3.1 `bash tests/run-all.sh` vert, ligne `shellcheck` de `CLAUDE.md` propre, `./setup.sh --list` inchangé ; `openspec validate menage --strict` vert
