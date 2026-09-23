## 1. Module `vpn`

- [ ] 1.1 `modules/65-vpn.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête (configuration reportée, décision du 23 sept 2026), `module_check` et `module_install` (D1), `module_configure` (D2) ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [ ] 1.2 `tests/test-vpn.sh` : les cas de D3 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `vpn` → Paramètres > Réseau > VPN > « + » propose OpenVPN et « Importer depuis un fichier » ; résumé : étape d'import du profil ; relance → « déjà fait » ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `vpn` — installation faite (date, versions), **configuration du profil reportée** (profil et méthode à retrouver auprès de l'équipe TI) ; `openspec validate vpn --strict` vert
