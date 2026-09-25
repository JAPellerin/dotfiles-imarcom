## 0. Prérequis

- [ ] 0.1 VM (snapshot « vierge », `base`, `1password`, `navigateur`, `spotify`) : se connecter à la main par « Continuer avec Google » et relever **pendant que Spotify tourne** `~/.config/spotify/prefs` (`autologin.username`), où s'ouvre la page Google (navigateur par défaut ou fenêtre du client) et les libellés exacts de l'écran de connexion ; consigner dans `design.md` (D1, D2) et les corriger si besoin

## 1. Module `spotify`

- [ ] 1.1 `modules/63-spotify.sh` : `SPOTIFY_PREFS` (surchargeable), sonde `_spotify_logged_in` (D1) ; `module_check` l'exige ; `module_install` sans étape manuelle ni variable `fresh` (D3) ; `module_configure` lance `guided_login` sans secret (D2) ; en-tête mis à jour (renvoi à ce change) ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [ ] 1.2 `tests/test-spotify.sh` : cas de D4, cas existants adaptés ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `navigateur`, `spotify` → Spotify s'ouvre, consigne affichée, connexion par Google (compte personnel, rempli par 1Password) → « Spotify : fait », aucune étape au résumé ; relance → « déjà fait », Spotify pas rouvert ; se déconnecter → `module_check` à faire, relance → parcours reproposé sans réinstallation ; « Passer » → étape manuelle au résumé ; aucun appel `op` pour Spotify au journal ; consigner ici
- [ ] 2.2 `ROADMAP.md` : vague 4, `spotify` fait (date) ; `openspec validate spotify-connexion --strict` vert
