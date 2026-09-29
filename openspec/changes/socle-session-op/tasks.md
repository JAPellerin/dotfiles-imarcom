## 0. Relevé

- [ ] 0.1 VM, terminal de la session graphique, application déverrouillée et intégration CLI active : `op whoami` (ouvre ou constate) ; attendre 11 minutes sans commande `op` ; `op whoami` → relever le message et le code ; `op signin` → la fenêtre d'autorisation apparaît, l'accepter ; `op whoami` → réussit ; consigner dans `design.md` (Context)

## 1. Runner

- [ ] 1.1 `setup.sh` : `_depends_on_op <module>` (fermeture de `MOD_DEPS`) et `_op_session_ensure_for` appelée avant `module_install` et avant `module_configure` dans `run_modules` (D1, D2) ; `modules/10-1password.sh` : `_op_connect` sans le message « seront sautés » quand le runner l'appelle (D2) et commentaire au-dessus (appelée par le runner) ; vérifier `shellcheck` propre
- [ ] 1.2 `tests/test-run.sh` et jeu factice `tests/fixtures/modules/` (D3, dont la session fermée entre `module_install` et `module_configure`) ; vérifier `bash tests/run-all.sh` vert

## 2. Validation

- [ ] 2.1 VM : `./setup.sh` avec `navigateur` puis un module qui lit 1Password (par ex. `vault` ou `projets`) ; laisser passer plus de 10 minutes pendant l'attente de Brave Sync ; au module suivant → message de réouverture, fenêtre d'autorisation, module sans étape « session » ; consigner ici ; `openspec validate socle-session-op --strict` vert
