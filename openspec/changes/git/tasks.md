## 1. Fichier versionné

- [x] 1.1 `config/git/gitconfig` : reprise de `~/.gitconfig` (identité, `init.defaultBranch`), section `delta` (`core.pager`, `interactive.diffFilter`, `delta.navigate`, `merge.conflictstyle=zdiff3`, `diff.colorMoved=default`), `[include] path = ~/.gitconfig.local` ; vérifier `git config --file config/git/gitconfig --list` et qu'un `~/.gitconfig.local` de test surcharge `user.email` (`GIT_CONFIG_GLOBAL`)

## 2. Module `git`

- [x] 2.1 `modules/30-git.sh` (`MODULE_GROUP=dev`, `MODULE_DEPS="base 1password"`) — `module_install` : `apt_install git-delta`, `apt_add_repo github-cli` (clé `.gpg` binaire) + `apt_install gh` ; vérifier dans la WSL : `delta --version`, `gh --version`, fichier `/etc/apt/sources.list.d/github-cli.sources` correct, réexécution sans `apt update`
- [x] 2.2 `module_configure` — `link_config config/git/gitconfig ~/.gitconfig` (après l'installation de delta), hôtes connus (D4, `ensure_line`, `ssh-keygen -F`), clé SSH selon D2 (`op_read` dans une variable, `umask 077`, jamais d'écrasement, `log_info` « agent 1Password » avec l'app), `gh auth login` guidé si `gh auth status` échoue ; `module_check` selon D6
- [x] 2.3 `tests/test-git.sh` avec `HOME` isolé et doublures (`dpkg-query`, `op`, `gh`, `curl`) : les 7 cas de D7 ; `bash tests/run-all.sh` vert, `shellcheck` propre (ajouter `config/git/gitconfig` à rien : pas un script)
- [ ] 2.4 Exécution réelle dans la WSL : `./setup.sh git` → dépôt `gh` ajouté, `gh` et `delta` installés, `~/.gitconfig` lié (`.bak`), `known_hosts` complété, clé existante non touchée (message), `gh auth login` réel réussi ; `git diff` dans le dépôt passe par delta ; relance → « déjà fait »

## 3. Documentation et VM

- [ ] 3.1 `CLAUDE.md` : convention des secrets (D1 : coffre `Private`, item par service, champs 1Password, `?ssh-format=openssh`, `op_read` dans une variable) ; `ROADMAP.md` : `git` fait, `git-delta` installé ici ; `openspec validate git --strict` vert
- [ ] 3.2 VM (snapshot « vierge ») : bootstrap → `base` + `1password` + `shell` + `git` → dans un nouveau terminal : `ssh -T git@github.com` (via l'agent, sans fichier de clé dans `~/.ssh`), `git clone git@github.com:JAPellerin/dotfiles-imarcom.git /tmp/t`, `git -C /tmp/t diff HEAD~1` affiché par delta, `gh auth status` ; relance → « déjà fait » partout
