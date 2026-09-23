## 1. Helpers de groupe

- [x] 1.1 `lib/groups.sh` : `user_in_group`, `ensure_user_in_group`, `group_relogin_step` selon D2, en-tête dans le style des autres `lib/*.sh` ; chargé par `setup.sh` ; vérifier `shellcheck lib/groups.sh setup.sh` propre et `./setup.sh --list` inchangé
- [x] 1.2 `tests/test-groups.sh` : les cas de D4 ; vérifier `bash tests/test-groups.sh` vert, et qu'une mutation (retirer `-x` de la comparaison, ou ignorer la session) le fait échouer

## 2. `docker` sur les helpers

- [x] 2.1 `modules/41-docker.sh` réécrit selon D3 ; vérifier `bash tests/test-docker.sh` vert sans modifier ses assertions, `shellcheck` propre, et dans la WSL `./setup.sh --list` → `docker` « déjà fait » — fait le 23 sept 2026 : `tests/test-docker.sh` vert (57 assertions) ; écart assumé avec D3 : trois assertions appelaient directement la fonction privée `_docker_user_in_group`, supprimée — elles appellent désormais `user_in_group docker`, mêmes attentes, et le test charge `lib/groups.sh` ; `module_check` réel sous `pipefail` dans la WSL → 0, `--list` → « déjà fait »

## 3. Vérification d'ensemble et documentation

- [x] 3.1 `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre ; `CLAUDE.md` : les trois helpers dans la liste des helpers du socle ; `ROADMAP.md` : `socle-groupes` noté avant `claude-desktop` dans la vague 2 ; `openspec validate socle-groupes --strict` vert
