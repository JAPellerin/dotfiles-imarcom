## 1. Module `thunderbird`

- [x] 1.1 `config/thunderbird/thunderbird.desktop` : le fichier `.desktop` publié par Mozilla (sumo-kb), `Exec` et `Icon` portant `@THUNDERBIRD_DIR@` (D3) ; vérifier `desktop-file-validate` sur une version rendue, s'il est disponible
- [x] 1.2 `modules/62-thunderbird.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base shell"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien de la doc de Mozilla, constantes, `module_check` (D4), `module_install` (D1, étape des comptes), `module_configure` (D2, D3) ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [x] 1.3 `tests/test-thunderbird.sh` : les cas de D5 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `thunderbird` → Thunderbird s'ouvre depuis le menu, en français, avec son icône ; `~/.local/share/thunderbird` appartient à l'utilisateur ; **Aide > À propos : la recherche de mise à jour fonctionne** (pas de « mise à jour impossible ») ; aucun snap ni paquet `thunderbird` installé ; comparer D2 à la méthode « dossier personnel » de la page de Mozilla (navigateur de la VM) ; résumé : étape des comptes ; relance → « déjà fait », aucun téléchargement ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `thunderbird` fait (date, version) ; `openspec validate thunderbird --strict` vert
