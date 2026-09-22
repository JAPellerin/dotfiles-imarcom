## 1. Fragment et intégration shell

- [ ] 1.1 `config/cli-tools/commonrc.sh` : les trois variables `FZF_*` de D3, en POSIX, sans garde `command -v` ; vérifier `shellcheck config/cli-tools/commonrc.sh` propre (le motif `git ls-files` de la ligne de lint le prend désormais) et qu'un chargement dans `sh`, `bash` et `zsh` définit `FZF_DEFAULT_COMMAND`
- [ ] 1.2 `config/shell/bashrc-extra.sh` : activation de `zoxide` et `fzf` sous garde `command -v` (D4, formes `zoxide init bash` et `fzf --bash`), à l'image des lignes 123-124 de `zshrc` ; vérifier `shellcheck` propre, `bash -ic true` sans message avec et sans les outils installés
- [ ] 1.3 `tests/test-shell.sh` : ajouter le cas « outils optionnels présents » de la spec modifiée (doublures `fzf` et `zoxide` dans le `PATH` → les deux shells démarrent sans erreur et l'initialisation a bien eu lieu) ; vérifier `bash tests/test-shell.sh` vert

## 2. Module `cli-tools`

- [ ] 2.1 `modules/22-cli-tools.sh` (`MODULE_GROUP=shell`, `MODULE_DEPS="base"`, pas de `NEEDS_GUI`) — métadonnées et `module_install` : `apt_install` des sept paquets ; vérifier dans la WSL que `./setup.sh --list` affiche le module et que `module_install` n'installe que les manquants
- [ ] 2.2 `module_configure` — liens `~/.local/bin/bat` et `~/.local/bin/fd` selon D1/D2 (cible résolue par `command -v`, fichier ordinaire laissé intact et signalé, échec nommé si le binaire est introuvable) et `link_config` du fragment ; `module_check` selon D5
- [ ] 2.3 `tests/test-cli-tools.sh` : les six cas de D6 avec `HOME` isolé et doublures (`dpkg-query` paramétrable, `run_sudo`, faux `batcat`/`fdfind`), plus le chargement réel du fragment dans `sh`, `bash` et zsh ; vérifier `bash tests/run-all.sh` vert et `shellcheck` propre sur l'ensemble

## 3. Vérification réelle et documentation

- [ ] 3.1 Exécution réelle dans la WSL : `./setup.sh cli-tools` → sept paquets installés, deux liens créés, fragment lié ; puis dans un nouveau terminal : `rg --version`, `fd --version`, `bat --version`, `lazygit --version`, `psql --version`, `z` défini, `Ctrl-R` et `Ctrl-T` actifs en zsh **et** en bash, et l'aperçu de `fzf` affiche un fichier coloré (preuve que `bat` est trouvé hors shell interactif, D1) ; relance → « déjà fait »
- [ ] 3.2 `ROADMAP.md` : `cli-tools` fait (date, version des paquets installés) ; `openspec validate cli-tools --strict` vert ; relire que `config/shell/commonrc` n'a pas été touché (`git diff` sur ce fichier vide)
