## 0. Prérequis

- [x] 0.1 (références confirmées par l'utilisateur le 25 sept 2026 ; reste la vérification par `op`) Élément 1Password : `op read op://Imarcom/RocketChat/username` répond (identifiant attendu) et `op read op://Imarcom/RocketChat/password >/dev/null` réussit, depuis une session active — **vérifié le 25 sept 2026** : les deux références répondent.
- [x] 0.2 VM (snapshot « vierge », `base`, `1password`, `rocketchat`) : se connecter à la main dans le client et relever **pendant qu'il tourne** `~/.config/Rocket.Chat/config.json` (serveur, `userLoggedIn`), la commande du lanceur (`grep Exec /usr/share/applications/rocketchat*.desktop`, `command -v rocketchat-desktop`) ; consigner dans `design.md` (D1, D2) et corriger D1 si le signe diffère — **fait le 25 sept 2026** : fichier écrit pendant que le client tourne, `userLoggedIn: true`, URL avec `/` final ; aucune commande dans le `PATH`, `ROCKETCHAT_BIN=/opt/Rocket.Chat/rocketchat-desktop`

## 1. Module `rocketchat`

- [ ] 1.1 `modules/61-rocketchat.sh` : constantes `ROCKETCHAT_USER_REF`, `ROCKETCHAT_PASSWORD_REF`, `ROCKETCHAT_CONFIG` (surchargeable), `ROCKETCHAT_BIN` (D2) ; sonde `_rocketchat_logged_in` (D1, URL lue dans `config/rocketchat/servers.json`) ; `module_check` l'exige ; `module_install` sans étape manuelle (D3) ; `module_configure` lance `guided_login` après `servers.json` et le profil AppArmor, dans tous les cas (D2) ; en-tête mis à jour (renvoi à ce change) ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [ ] 1.2 `tests/test-rocketchat.sh` : cas de D4, cas existants adaptés ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `rocketchat` → le client s'ouvre sur `rocketchat.imarcom.net`, l'identifiant s'affiche, coller le mot de passe → « Rocket.Chat : fait (presse-papiers vidé) », `wl-paste` vide, mot de passe absent de `~/.local/state/dotfiles/setup-*.log` ; relance → « déjà fait », aucun appel à `op` ; se déconnecter dans le client → `module_check` à faire, relance → parcours reproposé sans téléchargement ; « Passer » → étape manuelle au résumé ; consigner ici
- [ ] 2.2 `ROADMAP.md` : vague 4, `rocketchat` fait (date) ; `openspec validate rocketchat-connexion --strict` vert
