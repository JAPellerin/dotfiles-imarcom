## 1. Helpers de déploiement (`lib/files.sh`)

- [x] 1.1 `lib/files.sh` chargé par `setup.sh` : `link_config <rel> <cible>` (lien absolu, sauvegarde `.bak` puis datée, lien étranger remplacé, source absente → échec nommé) et `config_linked <rel> <cible>` ; `tests/test-files.sh` couvre les cinq cas de la spec, `shellcheck` propre
- [x] 1.2 `ensure_git_clone <url> <dossier> [--depth 1]` : clone via `run`, déjà cloné → rien, dossier étranger → échec nommé ; `tests/test-files.sh` avec un dépôt local `file://` (premier clonage, réexécution, dossier étranger)

## 2. Fichiers versionnés (`config/shell/`)

- [x] 2.1 Copier depuis la WSL `~/.zshrc` → `config/shell/zshrc`, `~/.commonrc` → `config/shell/commonrc`, `~/.p10k.zsh` → `config/shell/p10k.zsh` ; dans `zshrc` : `plugins=(git zsh-autosuggestions zsh-syntax-highlighting)` et intégrations conditionnelles `zoxide` / `fzf` (D3) ; vérifier `zsh -n config/shell/zshrc` et `sh -n config/shell/commonrc` (POSIX)
- [x] 2.2 `config/shell/bashrc-extra.sh` : chargement de `.commonrc`, complétion nvm si présente, `__git_ps1` + `PS1` (reprise du `.bashrc` actuel de la WSL) ; vérifier `bash -n` et `bash -c 'source config/shell/bashrc-extra.sh; echo $VAULT_ADDR'`

## 3. Module `shell`

- [x] 3.1 `modules/20-shell.sh` (`MODULE_GROUP=shell`, `MODULE_DEPS="base"`) — `module_install` : `apt_install zsh`, `ensure_git_clone` oh-my-zsh (complet), Powerlevel10k et les deux plugins (`--depth 1`) ; vérifier dans la WSL que la réexécution ne reclone rien
- [x] 3.2 `module_configure` : trois `link_config`, `ensure_line` de la ligne `bashrc-extra` dans `~/.bashrc`, `run_sudo chsh`, `log_info` nouvelle session + Nerd Font, `log_warn` si le `.bashrc` contient encore les anciens ajouts manuels ; `module_check` selon D6
- [x] 3.3 `tests/test-shell.sh` : `HOME` isolé et doublures (`dpkg-query`, `git`, `chsh`, `sudo`, `getent`) — première application (liens, `.bak`, ligne unique, `chsh` une fois), réexécution → `module_check` 0 et aucune commande relancée ; `bash tests/run-all.sh` vert, `shellcheck` propre sur tout
- [x] 3.4 Exécution réelle dans la WSL : `./setup.sh shell` → « fait », `ls -l ~/.zshrc ~/.commonrc ~/.p10k.zsh` pointent vers le dépôt, `.bak` présents, `zsh -ic true` silencieux, `bash -lc 'echo $VAULT_ADDR'` et `zsh -ic 'echo $VAULT_ADDR'` corrects, nouvelle fenêtre avec l'invite p10k intacte ; relance → « déjà fait » — fait le 18 sept 2026 : 2 plugins clonés, rien d'autre retéléchargé, liens + .bak, `zsh -ic true` silencieux sous pty, VAULT_ADDR OK dans bash et zsh, prompt p10k inchangé + autosuggestions/coloration, `--list` → déjà fait

## 4. Documentation et VM

- [x] 4.1 `ROADMAP.md` : `setup-socle` fait (archivé le 18 sept 2026), mécanisme de déploiement tranché (liens, `lib/files.sh`) ; `CLAUDE.md` : mention de `config/<module>/` + `link_config` dans le contrat de module ; `openspec validate shell --strict` vert
- [x] 4.2 VM (snapshot « vierge ») : `curl … bootstrap.sh | bash` → menu avec `shell` précoché → après exécution, ouvrir un nouveau terminal : zsh + p10k (glyphes cassés attendus sans Nerd Font), `echo $VAULT_ADDR`, `bash` puis `echo $VAULT_ADDR` et invite git ; relance → « déjà fait » partout — fait le 18 sept 2026 : `base` + `shell` (1password décoché dans le menu), zsh + 4 dépôts en 40 s, liens, ligne bash, `chsh`, nouveau terminal en zsh/p10k, `VAULT_ADDR` en zsh et bash interactif, `__git_ps1` ; relance : rien de précoché. Trouvé et corrigé : une annulation du menu (Échap) ne stoppait pas le runner (`die` dans `$(…)`), test ajouté dans `tests/test-run.sh`
