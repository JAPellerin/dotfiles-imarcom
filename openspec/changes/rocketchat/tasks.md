## 0. Prérequis

- [ ] 0.1 Le change `socle-github` est fait ; vérifier `grep -n 'github_release_asset_url()' lib/github.sh`

## 1. Module `rocketchat`

- [ ] 1.1 `config/rocketchat/servers.json` selon D2 ; vérifier `jq . config/rocketchat/servers.json`
- [ ] 1.2 `modules/61-rocketchat.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien du README (« Default servers »), `module_check` (D4), `module_install` (D1, D3), `module_configure` (D2) ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [ ] 1.3 `tests/test-rocketchat.sh` : les cas de D5 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `rocketchat` → le client s'ouvre depuis le menu **directement sur la page de connexion de `rocketchat.imarcom.net`** (D2) ; `dpkg -s rocketchat` → version du dernier `.deb` ; `~/.config/Rocket.Chat/servers.json` est un lien vers le dépôt ; résumé : étape de connexion ; relance → « déjà fait », aucun appel à GitHub ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `rocketchat` fait (date, version) ; `openspec validate rocketchat --strict` vert
