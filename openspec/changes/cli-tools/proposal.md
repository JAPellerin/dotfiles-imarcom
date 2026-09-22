## Why

Le poste a `jq`, `git` et `delta` ; il lui manque la trousse de ligne de commande utilisée au quotidien : chercher dans du code (`ripgrep`), trouver un fichier (`fd`), filtrer de façon interactive (`fzf`), lire un fichier avec coloration (`bat`), sauter dans un dossier visité (`zoxide`), conduire git sans quitter le terminal (`lazygit`) et se connecter à PostgreSQL (`psql`).

C'est aussi le **premier module qui dépose un fragment `~/.commonrc.d/`**, le point d'extension posé par la vague 0 : il inaugure la convention que les modules suivants (`node`, `docker`) reprendront, au lieu d'éditer `config/shell/commonrc`.

Tous ces outils sont dans les dépôts d'Ubuntu 26.04 en version récente (relevé le 22 sept 2026 : ripgrep 15.1.0, fd-find 10.3.0, fzf 0.67.0, bat 0.25.0, zoxide 0.9.8, lazygit 0.57.0, postgresql-client 18) : le module se résume à un `apt_install` et à la configuration shell qui les rend réellement utilisables.

## What Changes

- **Module `cli-tools`** (`modules/22-cli-tools.sh`, groupe `shell`, dépend de `base`, sans session graphique) :
  - `apt_install ripgrep fd-find fzf bat zoxide lazygit postgresql-client` depuis les dépôts Ubuntu ;
  - **`bat` et `fd` sous leur vrai nom** : sur Debian et Ubuntu, ces deux paquets installent `batcat` et `fdfind` pour cause de collision de noms avec d'autres paquets. Le module crée `~/.local/bin/bat` et `~/.local/bin/fd`, liens vers les binaires du système (`~/.local/bin` est déjà dans le `PATH` par `commonrc`) ;
  - **fragment `config/cli-tools/commonrc.sh`** lié vers `~/.commonrc.d/cli-tools.sh` par `link_config` : réglages `fzf` communs aux deux shells (`FZF_DEFAULT_COMMAND` et `FZF_CTRL_T_COMMAND` fondés sur `fd`, `FZF_DEFAULT_OPTS` avec aperçu par `bat`) ;
  - `module_check` : les sept paquets installés, les deux liens de `~/.local/bin` en place, le fragment lié (`config_linked`).
- **`config/shell/bashrc-extra.sh`** : activation de `fzf` et `zoxide` sous garde `command -v`, comme `config/shell/zshrc` le fait déjà pour zsh. Sans cela, les deux outils installés par ce module ne serviraient qu'en zsh.

Hors périmètre, assumé explicitement :

- **`yq`** — retiré de la liste du `ROADMAP.md` le 22 sept 2026 : arrivé avec la trousse « CLI moderne » standard, sans besoin derrière. Réintégrable en une ligne.
- **`eza`, `duf`, `procs`, `httpie`…** — même raisonnement : on ajoute quand un besoin se présente, pas par exhaustivité.
- **Configuration de `lazygit`** (`~/.config/lazygit/config.yml`) — ses valeurs par défaut conviennent ; un fichier versionné s'ajoutera le jour où un réglage manque.
- **Connexions PostgreSQL** (`~/.pgpass`, `~/.psqlrc`) — dépendent des serveurs, donc du module `projets`, pas d'ici. Seul le client est installé.
- **Serveur PostgreSQL** — le module installe `postgresql-client` seul ; une base locale relève de `docker`.
- **Thème de `bat` et de `delta`** — `delta` est configuré par le module `git` ; harmoniser les thèmes des deux n'est pas l'objet de ce module.

## Capabilities

### New Capabilities
- `module-cli-tools` : le module `cli-tools` — installation des sept outils depuis les dépôts Ubuntu, rétablissement des noms `bat` et `fd`, fragment de configuration shell commun.

### Modified Capabilities
- `module-shell` : l'exigence « Fichiers de configuration liés depuis le dépôt » évolue — `bashrc-extra.sh` active `fzf` et `zoxide` sous garde, au même titre que `.zshrc`.

## Impact

- Nouveaux `modules/22-cli-tools.sh`, `config/cli-tools/commonrc.sh`, `tests/test-cli-tools.sh` ; `config/shell/bashrc-extra.sh` complété.
- Premier usage réel de la convention des fragments (`openspec/specs/config-files/spec.md`) : ce module sert de modèle aux suivants.
- Fichiers créés hors dépôt : `~/.local/bin/bat` et `~/.local/bin/fd` (liens vers `/usr/bin/batcat` et `/usr/bin/fdfind`), `~/.commonrc.d/cli-tools.sh` (lien vers le dépôt).
- Aucun dépôt apt tiers, aucun secret, aucun téléchargement : tout vient des dépôts Ubuntu.
- Testable et vérifiable intégralement dans la WSL (pas de `MODULE_NEEDS_GUI`) — contrairement à `navigateur`, aucune étape ne demande la VM.
- Docs : `ROADMAP.md` (`cli-tools` fait).
