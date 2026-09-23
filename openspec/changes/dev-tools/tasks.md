## 1. Module `dev-tools`

- [x] 1.1 `modules/42-dev-tools.sh` (`MODULE_GROUP=dev`, `MODULE_DEPS="base shell"`, pas de `NEEDS_GUI`) — en-tête avec les liens des deux docs, constantes (URL des installateurs, chemins), `_dev_tools_run_installer` (D1), `PATH` (D2) et `module_install` (D3, D4) ; vérifier `shellcheck` propre et `./setup.sh --list` → `dev-tools` dans `[dev]`, « déjà fait » dans la WSL
- [x] 1.2 `module_configure` : étapes de connexion selon D5 ; `module_check` selon D6 ; vérifier `shellcheck` propre
- [x] 1.3 `tests/test-dev-tools.sh` : les cas de D8 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation réelle et documentation

- [x] 2.1 WSL : `./setup.sh dev-tools` (terminal) → « déjà fait », aucun installateur lancé (journal) ; consigner ici — **fait le 23 sept 2026** : `./setup.sh dev-tools` lancé par l'utilisateur (journal `setup-20260923-121526.log`) → `base`, `shell` et `dev-tools` « déjà fait », aucune commande exécutée ; Claude Code 2.1.280 et twg 1.3.1 existants laissés tels quels ; `git status` propre
- [ ] 2.2 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `shell`, `dev-tools` → `claude --version` et `twg --help` dans un nouveau terminal ; **`git -C ~/dotfiles status` propre et `~/.bashrc`, `~/.profile` sans ligne ajoutée** (D2) ; résumé final avec les deux étapes de connexion ; `twg login` et `claude` faits à la main → relance : « déjà fait », plus d'étape ; consigner ici (et corriger D2 si un installateur a écrit quelque part)
- [ ] 2.3 `ROADMAP.md` : `dev-tools` fait (date, versions), dépendance à `node` retirée (vague 2 sans dépendance interne) ; `openspec validate dev-tools --strict` vert
