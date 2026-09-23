## 1. Module `vscode`

- [x] 1.1 `config/vscode/extensions.txt` : les 18 identifiants décidés, triés, avec un en-tête en commentaire ; vérifier qu'il correspond exactement à la liste de la proposition
- [x] 1.2 `modules/51-vscode.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien de la doc Linux de VS Code, constantes, `module_install` : sélection debconf (D2), `apt_add_repo` (D1), `apt_install code gnome-keyring` ; vérifier `shellcheck` propre et `./setup.sh --list` → `vscode` « non disponible ici » dans la WSL
- [x] 1.3 `module_configure` : extensions selon D3 ; `module_check` selon D4 ; vérifier `shellcheck` propre
- [x] 1.4 `tests/test-vscode.sh` : les cas de D6 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre
- [x] 1.5 Étape manuelle de connexion Jira et Bitbucket selon D6b (demande de l'utilisateur, 23 sept 2026) ; cas de test correspondants dans `tests/test-vscode.sh` ; vérifier `bash tests/run-all.sh` vert et `shellcheck` propre

## 2. Validation en VM et documentation

- [x] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `vscode` → VS Code s'ouvre depuis le menu ; `code --list-extensions` → les 18 ; `ls /etc/apt/sources.list.d/` → **un seul** `vscode.sources`, pointant sur `/etc/apt/keyrings/vscode.asc` (D1, D2) ; `debconf-show code` → `add-microsoft-repo: false` ; relance → « déjà fait », `vscode.sources` non réécrit (même date) ; consigner ici, et corriger D2 si le paquet a écrit son dépôt — **validé le 23 sept 2026** : code 1.139.0 et gnome-keyring 50.0 installés ; **un seul `vscode.sources`** (Signed-By `/etc/apt/keyrings/vscode.asc`, écrit à 13:36:45 et jamais réécrit depuis) ; debconf `code/add-microsoft-repo` = `false` (lu dans `/var/cache/debconf/config.dat`) — **D2 tient** ; `code --list-extensions` → les 18 ; VS Code ouvert depuis le menu, confirmé par l'utilisateur ; `module_check` → 0. L'étape manuelle Jira/Bitbucket (1.5, ajoutée après ce passage, puis déplacée dans `module_install` à la contre-vérification — D6b) **confirmée le 23 sept 2026** au passage de `claude-desktop` depuis le snapshot vierge (avec `base`, `1password`, `vscode`) : l'étape figure au résumé final (correctif `164558e`)
- [x] 2.2 `ROADMAP.md` : `vscode` fait (date, version) ; `openspec validate vscode --strict` vert — fait le 23 sept 2026
