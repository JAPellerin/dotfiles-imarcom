## 0. Prérequis

- [x] 0.1 Le change `socle-github` est fait ; vérifier `grep -n 'github_release_asset_url()' lib/github.sh`

## 1. Module `rocketchat`

- [x] 1.1 `config/rocketchat/servers.json` selon D2 ; vérifier `jq . config/rocketchat/servers.json`
- [x] 1.2 `modules/61-rocketchat.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien du README (« Default servers »), `module_check` (D4, `cmp -s`), `module_install` (D1, D3), `module_configure` (D2, `install_system_file` vers `$ROCKETCHAT_ROOT/opt/Rocket.Chat/resources/servers.json`) — révisé le 24 sept 2026 : plus de lien dans `~/.config/Rocket.Chat/` ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [x] 1.3 `tests/test-rocketchat.sh` : les cas de D5 (révisés le 24 sept 2026) ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

- [x] 1.4 Profil AppArmor (D6, ajouté le 24 sept 2026 après le plantage en VM) : `config/rocketchat/apparmor-profile` ; `module_configure` le copie vers `$ROCKETCHAT_ROOT/etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin` (pas `rocketchat-desktop`, que le `postrm` du paquet supprime à chaque mise à jour) et le charge s'il vient d'être écrit (retiré si le chargement échoue) ; `module_check` compare aussi le profil (D4) ; cas de D5 dans `tests/test-rocketchat.sh` ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `rocketchat` → le client s'ouvre depuis le menu **sans plantage** (D6 ; `/etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin` identique au dépôt, aucun `DENIED … rocketchat` dans `journalctl -k`) et **directement sur la page de connexion de `rocketchat.imarcom.net`** (D2) ; `dpkg -s rocketchat` → version du dernier `.deb` ; `/opt/Rocket.Chat/resources/servers.json` identique au dépôt, `dpkg -S /opt/Rocket.Chat/resources/servers.json` → aucun paquet ; résumé : étape de connexion ; après le premier lancement du client, relance → « déjà fait », aucun appel à GitHub ; installer le `.deb` précédent puis le dernier (`sudo apt install ./…`) → `servers.json` et le profil AppArmor toujours là, `module_check` → déjà fait ; consigner ici
- [ ] 2.2 `ROADMAP.md` : `rocketchat` fait (date, version) ; `openspec validate rocketchat --strict` vert
