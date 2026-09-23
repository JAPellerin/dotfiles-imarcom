## 1. Module `node`

- [ ] 1.1 `modules/40-node.sh` (`MODULE_GROUP=dev`, `MODULE_DEPS="base shell"`, pas de `NEEDS_GUI`) — en-tête avec les liens de la doc de nvm, constantes (URL, étiquette `v0.40.8`, `pnpm@11`, paquet openspec), `_node_nvm` (D2) et `module_install` selon D1, D3, D4 ; vérifier `shellcheck` propre et `./setup.sh --list` qui affiche `node` dans `[dev]`
- [ ] 1.2 `module_check` selon D5 ; vérifier dans la WSL qu'il retourne 1 (aucune LTS installée), en moins d'une seconde et sans réseau (seulement des lectures de fichiers et `nvm version`)
- [ ] 1.3 `tests/test-node.sh` : les cas de D7 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation réelle et documentation

- [ ] 2.1 WSL : `./setup.sh node` (dans un terminal, pour `sudo -v`) → LTS installée avec son pnpm 11, la 26 reste par défaut ; `ls ~/.nvm/versions/node` → la LTS et **la seule v26.8.2** (aucune nouvelle 26, D3) ; dans un nouveau shell : `node --version` → v26, `nvm exec --lts pnpm --version` → 11, `openspec --version` ; `git -C ~/dotfiles status` propre (aucun fichier du shell modifié) ; relance → « déjà fait » ; consigner ici
- [ ] 2.2 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `shell`, `node` → mêmes vérifications depuis zéro, dans un nouveau terminal ; `~/.nvm` à l'étiquette `v0.40.8` ; `pnpm --version` dans un dossier contenant un `package.json` avec `"packageManager": "pnpm@11.20.0"` → `11.20.0` ; relance → « déjà fait » ; consigner ici
- [ ] 2.3 `ROADMAP.md` : `node` fait (date, versions), contenu corrigé (« LTS + 26, pnpm 11 ») ; `openspec validate node --strict` vert
