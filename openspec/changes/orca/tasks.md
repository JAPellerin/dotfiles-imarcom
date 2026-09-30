## 1. Module `orca`

- [x] 1.1 `config/orca/apparmor-profile` (D3, commentaires en tête sur le modèle de celui de `rocketchat`) ; `modules/53-orca.sh` (`MODULE_GROUP=apps`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`, description de D1) — en-tête avec liens officiels, constantes, `module_check`, `module_install` (D1, D2), `module_configure` (profil, D3) ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL — **fait le 30 sept 2026**
- [x] 1.2 `tests/test-orca.sh` : cas de D5 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre — **fait le 30 sept 2026** : 44 assertions (dont profil écrit et chargé une fois, relance sans rechargement, profil modifié ou retiré, chargement en échec → profil retiré)

## 2. Dock

- [x] 2.1 `config/gnome/reglages.dconf` : `orca-ide.desktop` entre 1Password et VS Code (D4) ; `tests/test-gnome.sh` : liste attendue ; vérifier `bash tests/test-gnome.sh` vert — **fait le 30 sept 2026**

## 3. Validation en VM et documentation

- [ ] 3.1 VM, **avant** `git pull` : `dconf reset /org/gnome/shell/favorite-apps`, réouverture de session → `dconf read` du dock = liste actuelle du dépôt (sans Orca) ; puis `git pull` et `./setup.sh orca` → `dpkg -s orca-ide` à la version du dernier `.deb` ; profil `/etc/apparmor.d/opt.Orca.orca-ide` chargé (`sudo aa-status | grep -i orca`) ; Orca démarre depuis le menu sans plantage ; `orca-ide --help` répond depuis le PATH ; résumé : étape « ajouter ses dépôts » ; relance → « déjà fait », aucun appel à GitHub ; consigner ici
- [ ] 3.2 VM : `./setup.sh gnome` → réglages recopiés, « Dock mis à jour » (D9 de `gnome`, **sans** remise à zéro) ; `dconf read` du dock → Orca entre 1Password et VS Code, affiché à l'écran ; consigner ici
- [ ] 3.3 `ROADMAP.md` : ligne 53 `orca` au tableau ; vague 6 (`orca`, `solaar`, demandée le 30 sept 2026) dans « Ordre des changes » ; `openspec validate orca --strict` vert
