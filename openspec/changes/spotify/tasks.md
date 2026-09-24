## 1. Module `spotify`

- [x] 1.1 `modules/63-spotify.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien de la page Linux de Spotify, constantes (URL de clé et de dépôt, suite, composant, paquet), `module_check`, `module_install` (D1, D2), `module_configure` vide ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [x] 1.2 `tests/test-spotify.sh` : les cas de D4 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre
- [x] 1.3 Anti-doublon (design D3, contre-vérification du 24 sept 2026) : `config/spotify/spotify.list` (commentaires seuls, aucune ligne `deb`) posé par `install_system_file` avant `apt_add_repo`/`apt_install` ; `module_check` compare ce fichier au versionné (cible surchargeable par `SPOTIFY_ETC` pour les tests) ; en-tête du module corrigé ; `tests/test-spotify.sh` complété (D4 : fichier posé avant le paquet, sans `deb`, rétabli s'il est supprimé ou modifié, rien de réécrit à la relance) ; `bash tests/run-all.sh` vert et `shellcheck` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `spotify` → Spotify s'ouvre depuis le menu ; `apt-cache policy spotify-client` → `repository.spotify.com` ; `spotify.list` sans ligne `deb` après installation (le `postinst` ne l'a pas réécrit) et `grep -rhE '^(deb |URIs:).*spotify' /etc/apt/sources.list.d/` → une seule ligne ; `sudo apt update` sans erreur ni avertissement sur Spotify ; `ls /etc/apt/trusted.gpg.d/` → noter la clé copiée par le paquet (D3) ; résumé : étape de connexion ; relance → « déjà fait » ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `spotify` fait (date, version), « facultatif » retiré ; `openspec validate spotify --strict` vert
