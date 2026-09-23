## 0. Prérequis

- [x] 0.1 Le change `socle-groupes` est fait (helpers `user_in_group`, `ensure_user_in_group`, `group_relogin_step` présents dans `lib/groups.sh`) ; vérifier `grep -n 'ensure_user_in_group()' lib/groups.sh`

## 1. Module `claude-desktop`

- [x] 1.1 `config/claude-desktop/claude-desktop.default` : la seule ligne `CLAUDE_DESKTOP_ADD_REPO="false"` avec un commentaire renvoyant à la doc ; vérifier qu'elle reprend exactement le nom de variable de la doc
- [x] 1.2 `modules/52-claude-desktop.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`) — en-tête avec le lien de la doc Linux, constantes, `module_install` selon D1, D2, D3 (réglage avant paquet), plus l'étape de connexion de D5 quand le paquet vient d'être installé ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [x] 1.3 `module_configure` : Cowork (D4) ; `module_check` selon D5 ; vérifier `shellcheck` propre
- [x] 1.4 `tests/test-claude-desktop.sh` : les cas de D7 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `claude-desktop` → Claude s'ouvre depuis le menu ; `ls /etc/apt/sources.list.d/` → **un seul** fichier du dépôt d'Anthropic (`claude-desktop.sources`, pas de `claude-desktop.list`) et `apt update` sans « configured multiple times » (D1, D2) ; `apt-cache policy claude-desktop` pointe sur `downloads.claude.ai` ; `dpkg -l qemu-system-x86 ovmf virtiofsd` installés ; `getent group kvm` liste l'utilisateur ; résumé : réouverture de session (groupe `kvm`) et connexion ; relance → « déjà fait » ; consigner ici (et corriger D1/D2 si le paquet a écrit son `.list`)
- [ ] 2.2 `ROADMAP.md` : `claude-desktop` fait (date, version) ; `openspec validate claude-desktop --strict` vert
