## 1. Module `vscode`

- [ ] 1.1 `config/vscode/extensions.txt` : les 18 identifiants décidés, triés, avec un en-tête en commentaire ; vérifier qu'il correspond exactement à la liste de la proposition
- [ ] 1.2 `modules/51-vscode.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien de la doc Linux de VS Code, constantes, `module_install` : sélection debconf (D2), `apt_add_repo` (D1), `apt_install code gnome-keyring` ; vérifier `shellcheck` propre et `./setup.sh --list` → `vscode` « non disponible ici » dans la WSL
- [ ] 1.3 `module_configure` : extensions selon D3 ; `module_check` selon D4 ; vérifier `shellcheck` propre
- [ ] 1.4 `tests/test-vscode.sh` : les cas de D6 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `vscode` → VS Code s'ouvre depuis le menu ; `code --list-extensions` → les 18 ; `ls /etc/apt/sources.list.d/` → **un seul** `vscode.sources`, pointant sur `/etc/apt/keyrings/vscode.asc` (D1, D2) ; `debconf-show code` → `add-microsoft-repo: false` ; relance → « déjà fait », `vscode.sources` non réécrit (même date) ; consigner ici, et corriger D2 si le paquet a écrit son dépôt
- [ ] 2.2 `ROADMAP.md` : `vscode` fait (date, version) ; `openspec validate vscode --strict` vert
