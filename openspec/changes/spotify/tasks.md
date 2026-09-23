## 1. Module `spotify`

- [ ] 1.1 `modules/63-spotify.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien de la page Linux de Spotify, constantes (URL de clé et de dépôt, suite, composant, paquet), `module_check`, `module_install` (D1, D2), `module_configure` vide ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [ ] 1.2 `tests/test-spotify.sh` : les cas de D4 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `spotify` → Spotify s'ouvre depuis le menu ; `apt-cache policy spotify-client` → `repository.spotify.com` ; `ls /etc/apt/sources.list.d/` → **un seul** fichier de dépôt Spotify (D3) ; résumé : étape de connexion ; relance → « déjà fait » ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `spotify` fait (date, version), « facultatif » retiré ; `openspec validate spotify --strict` vert
