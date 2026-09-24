## 0. Prérequis

- [x] 0.1 Le change `socle-github` est fait ; vérifier `grep -n 'github_release_asset_url()' lib/github.sh`

## 1. Module `rocketchat`

- [x] 1.1 `config/rocketchat/servers.json` selon D2 ; vérifier `jq . config/rocketchat/servers.json`
- [x] 1.2 `modules/61-rocketchat.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien du README (« Default servers »), `module_check` (D4, `cmp -s`), `module_install` (D1, D3), `module_configure` (D2, `install_system_file` vers `$ROCKETCHAT_ROOT/opt/Rocket.Chat/resources/servers.json`) — révisé le 24 sept 2026 : plus de lien dans `~/.config/Rocket.Chat/` ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [x] 1.3 `tests/test-rocketchat.sh` : les cas de D5 (révisés le 24 sept 2026) ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `rocketchat` → le client s'ouvre depuis le menu **directement sur la page de connexion de `rocketchat.imarcom.net`** (D2) ; `dpkg -s rocketchat` → version du dernier `.deb` ; `/opt/Rocket.Chat/resources/servers.json` identique au dépôt, `dpkg -S /opt/Rocket.Chat/resources/servers.json` → aucun paquet ; résumé : étape de connexion ; après le premier lancement du client, relance → « déjà fait », aucun appel à GitHub ; installer le `.deb` précédent puis le dernier (`sudo apt install ./…`) → le fichier est toujours là, `module_check` → déjà fait ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `rocketchat` fait (date, version) ; `openspec validate rocketchat --strict` vert
