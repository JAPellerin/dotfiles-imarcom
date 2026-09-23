## 0. Prérequis

- [ ] 0.1 Le change `socle-github` est fait (`github_release_asset_url` dans `lib/github.sh`) ; vérifier `grep -n 'github_release_asset_url()' lib/github.sh`

## 1. Module `obsidian`

- [ ] 1.1 `modules/60-obsidian.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête, constantes (dépôt, motif, paquet, texte de l'étape), `module_check` et `module_install` selon D1 à D3, `module_configure` vide ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [ ] 1.2 `tests/test-obsidian.sh` : les cas de D5 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `obsidian` → Obsidian s'ouvre depuis le menu ; `dpkg -s obsidian` → version du dernier `.deb` publié ; journal : l'URL vient de la dernière release **qui contient** le `.deb` ; résumé : étape « ouvrir le coffre » ; relance → « déjà fait », aucun appel à GitHub dans le journal ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `obsidian` fait (date, version) ; `openspec validate obsidian --strict` vert
