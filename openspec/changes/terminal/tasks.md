## 1. Helper de police : fichiers en plus des archives

- [x] 1.1 `lib/fonts.sh` : nouvelle signature `install_font <famille> <dossier> <url...>` et traitement par extension (`.zip` extraite, `.ttf`/`.otf` installée telle quelle, nom de base décodé), le reste du déroulé inchangé (D2) ; vérifier `shellcheck lib/fonts.sh` propre
- [x] 1.2 `tests/test-fonts.sh` : les neuf appels passés à la nouvelle signature, plus les deux cas de D7 (installation depuis plusieurs URL de fichiers servies en `file://` ; une URL manquante → échec la nommant, aucun dossier laissé) ; vérifier `bash tests/test-fonts.sh` vert
- [x] 1.3 `CLAUDE.md` : la ligne des helpers du socle décrit `install_font` avec sa nouvelle signature ; vérifier qu'aucun autre appelant n'est resté sur l'ancienne (`grep -rn install_font`)

## 2. Module `terminal`

- [ ] 2.1 `config/terminal/ghostty` : les deux réglages de D3 (`font-family`, `font-size`), sans thème ; vérifier que le fichier est versionné et qu'aucune valeur n'y est inventée
- [ ] 2.2 `modules/21-terminal.sh` (`MODULE_GROUP=shell`, `MODULE_DEPS="base shell"`, `MODULE_NEEDS_GUI=1`) — métadonnées, constantes (famille `MesloLGS NF`, les quatre URL, dossier de police) et `module_install` : `apt_install ghostty` puis `install_font` ; vérifier que `./setup.sh --list` affiche le module comme « non disponible ici » dans la WSL
- [ ] 2.3 `module_configure` — `link_config` de la configuration, puis terminal par défaut selon D4 (alternative Debian enregistrée puis sélectionnée ; `gsettings` seulement si le schéma existe ; vérification après coup ; `manual_step` si rien ne se constate) ; `module_check` selon D6 sur ses quatre conditions
- [ ] 2.4 `tests/test-terminal.sh` : les cas de D7 avec `HOME` isolé et doublures (`dpkg-query`, `run_sudo` comptant `apt-get` et `update-alternatives`, `fc-list`/`fc-cache`, `gsettings` avec ou sans schéma) ; vérifier `bash tests/run-all.sh` vert et `shellcheck` propre sur l'ensemble

## 3. Validation en VM et documentation

- [ ] 3.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `shell`, `terminal` → Ghostty s'ouvre depuis le menu, son texte est en `MesloLGS NF`, **le prompt Powerlevel10k affiche ses icônes sans carré vide** (l'objet même de la police), `fc-list : family | grep -x 'MesloLGS NF'` répond, `~/.config/ghostty/config` est un lien ; relance → « déjà fait »
- [ ] 3.2 VM — terminal par défaut (D4) : établir **quel mécanisme agit réellement** sur Ubuntu 26.04 en testant `Ctrl+Alt+T` et « Ouvrir dans un terminal » de Fichiers, après l'alternative seule puis après le `gsettings` ; consigner le constat dans `design.md` (D4) et n'ajouter `~/.config/xdg-terminals.list` que si les deux premiers gestes ne suffisent pas
- [ ] 3.3 `ROADMAP.md` : `terminal` fait (date, version de Ghostty, police) ; `openspec validate terminal --strict` vert
