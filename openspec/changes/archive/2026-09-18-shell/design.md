## Context

Voir `proposal.md`. État observé dans la WSL de développement (18 sept 2026) : zsh 5.9, oh-my-zsh cloné dans `~/.oh-my-zsh`, Powerlevel10k dans `custom/themes/`, `.zshrc` = gabarit oh-my-zsh + instant prompt + `plugins=(git)` + `.p10k.zsh` + `.commonrc` + complétion nvm ; `.commonrc` POSIX (PATH `~/.local/bin`, nvm, `VAULT_ADDR`) ; `.bashrc` Ubuntu + `.commonrc` + `__git_ps1`. Le socle offre `ensure_line`, `run`, `apt_install`, `ui_*`, `manual_step` ; les modules tournent en sous-shell.

## Goals / Non-Goals

**Goals :** un mécanisme de déploiement des fichiers de config unique et réutilisable ; le shell de la WSL et du laptop identiques, versionnés ; zéro question à l'utilisateur (rien à choisir) ; testable hors ligne.

**Non-Goals :** gérer des fichiers différents par machine (templates) — si le besoin apparaît, `chezmoi` sera évalué ; installer les outils optionnels (`fzf`, `zoxide`, nvm) ; la police du terminal.

## Decisions

### D1. Liens symboliques absolus, un helper dans `lib/files.sh`
`link_config <chemin-relatif-au-dépôt> <cible>` : `ln -sfn "$DOTFILES_DIR/<rel>" <cible>` après sauvegarde d'un fichier ordinaire (`<cible>.bak`, puis `<cible>.bak-YYYYmmdd-HHMMSS` si `.bak` existe). `config_linked <rel> <cible>` : `[[ -L cible && $(readlink -f cible) == $(readlink -f source) ]]`. Liens absolus (le dépôt est à un endroit fixe, `DOTFILES_DIR`) ; un lien relatif casserait si `~/dotfiles` était déplacé de toute façon. Fichiers du dépôt **sans point initial** (`config/shell/zshrc`) pour rester visibles.
Alternatives : `stow` (arborescence miroir, un paquet de plus, même résultat) ; `chezmoi` (copies + templates + secrets, doublonne le runner ; réévalué si des différences par machine apparaissent) ; copie (`cp`) — perd le lien entre `~` et le dépôt, les modifications locales ne remontent plus.

### D2. `ensure_git_clone <url> <dossier> [--depth 1]` dans `lib/files.sh`
Clone via `run git clone` (sortie au journal) ; si le dossier existe : `git -C <dossier> remote get-url origin` doit égaler l'URL, sinon échec nommé ; pas de `pull` par défaut (mise à jour = décision explicite : oh-my-zsh a son propre `omz update`). `--depth 1` pour Powerlevel10k et les plugins (recommandé par leurs README) ; oh-my-zsh cloné complet (son mécanisme de mise à jour en a besoin).
Alternative rejetée : l'installateur `install.sh` d'oh-my-zsh (`--unattended --keep-zshrc`) — exécute un script téléchargé, modifie `.zshrc`/`chsh` selon des variables ; le README documente aussi le clone manuel, plus prévisible.

### D3. Contenu versionné = fichiers actuels
`config/shell/zshrc`, `commonrc`, `p10k.zsh` copiés depuis la WSL à l'apply (tâche dédiée), avec deux ajouts dans `zshrc` : `plugins=(git zsh-autosuggestions zsh-syntax-highlighting)` (syntax-highlighting en dernier, exigence de son README) et, après `oh-my-zsh.sh`, `command -v zoxide >/dev/null && eval "$(zoxide init zsh)"` et `command -v fzf >/dev/null && source <(fzf --zsh)` (fzf ≥ 0.48, celui d'Ubuntu 26.04). `.p10k.zsh` (1739 lignes générées) est versionné tel quel : c'est la seule façon d'avoir la même invite partout sans rejouer l'assistant. `VAULT_ADDR` reste (URL publique de l'entreprise, pas un secret).

### D4. bash : une ligne dans le `.bashrc` d'Ubuntu
`config/shell/bashrc-extra.sh` reprend ce qui a été ajouté à la main dans la WSL (chargement de `.commonrc`, complétion nvm, `__git_ps1` avec `PS1`) ; le module fait `ensure_line ~/.bashrc '[ -r "<DOTFILES_DIR>/config/shell/bashrc-extra.sh" ] && . "<DOTFILES_DIR>/config/shell/bashrc-extra.sh"'`. Versionner `.bashrc` entier obligerait à suivre celui d'Ubuntu ; le lien symbolique sur `.bashrc` aussi. Dans la WSL, les anciennes lignes ajoutées à la main (`.commonrc`, bloc git) restent : doublon inoffensif (`.commonrc` chargé deux fois, PS1 réaffecté) — à nettoyer à la main, signalé par `log_warn` si détecté.

### D5. Shell de connexion
`run_sudo chsh -s "$(command -v zsh)" "$USER"` (évite l'invite de mot de passe de `chsh` : le ticket sudo est là). `module_check` : `getent passwd "$USER" | cut -d: -f7` == chemin de zsh. Effet à la prochaine session : `log_info`, pas `manual_step` (rien à faire).

### D6. `module_check`
Vrai si : `zsh` installé ; `~/.oh-my-zsh/oh-my-zsh.sh`, thème et deux plugins présents ; trois liens en place (`config_linked`) ; ligne `bashrc-extra` présente ; shell de connexion = zsh. Tout est constaté, rien n'est mémorisé.

### D7. Tests
`tests/test-files.sh` : `link_config` (première application avec `.bak`, réapplication sans effet, `.bak` existant → daté, lien étranger remplacé sans sauvegarde, source absente → échec) et `ensure_git_clone` sur un dépôt local (`git init` dans `$TEST_TMP` + URL `file://`, dossier étranger → échec). `tests/test-shell.sh` : `module_check`/`module_install`/`module_configure` avec `HOME=$TEST_TMP/home`, `dpkg-query`/`git`/`chsh`/`sudo` factices : liens, ligne bashrc unique, `chsh` appelé une fois, réexécution → « déjà fait ». Exécution réelle dans la WSL (le module y remplace les vrais fichiers par des liens vers le dépôt : contenu identique) et en VM.

## Risks / Trade-offs

- [Le `.zshrc` versionné référence `~/.p10k.zsh` et `.commonrc` par chemin `~` : si un lien manque, zsh démarre quand même] → chaque `source` est déjà conditionnel dans le fichier actuel.
- [Powerlevel10k sans Nerd Font affiche des glyphes cassés (laptop avant `terminal`, WSL selon Windows Terminal)] → le module l'annonce (`log_info`) ; la police arrive avec `terminal`.
- [Instant prompt de p10k + sortie console pendant l'init (nvm, avertissements)] → l'ordre actuel du `.zshrc` est conservé (instant prompt en tête) ; `POWERLEVEL9K_INSTANT_PROMPT=verbose` déjà dans `.p10k.zsh` signale tout écart.
- [`chsh` refuse si zsh n'est pas dans `/etc/shells`] → le paquet Ubuntu l'y ajoute ; vérifié par `module_check` a posteriori.
- [Modifier `config/shell/zshrc` dans le dépôt modifie le shell courant à la prochaine ouverture] → voulu : c'est le principe du lien.
