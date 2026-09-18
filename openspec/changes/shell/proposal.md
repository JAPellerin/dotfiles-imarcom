## Why

Le socle est en place et éprouvé ; le premier module « métier » est le shell, parce qu'il tranche une question dont tous les modules suivants dépendent : **comment les fichiers de configuration versionnés dans le dépôt arrivent dans `~`**. Sans ce mécanisme, chaque module réinventerait sa copie ; avec lui, `git`, `terminal`, `gnome`… n'ont qu'à déclarer leurs fichiers.

## What Changes

- **Déploiement des fichiers de config par liens symboliques** (décision du 18 sept 2026, `chezmoi` reste possible plus tard) : les fichiers vivent dans `config/<module>/` dans le dépôt ; un helper du socle crée `~/.zshrc → ~/dotfiles/config/shell/zshrc`, sauvegarde un vrai fichier préexistant (`.bak`), ne fait rien si le lien est déjà bon, et sait dire si un lien est en place (pour `module_check`). Un second helper clone ou met à jour un dépôt git de façon idempotente (oh-my-zsh, thème, plugins ; réutilisable par `node` pour nvm).
- **Module `shell`** (`modules/20-shell.sh`, groupe `shell`, dépend de `base`) :
  - `zsh` (apt), oh-my-zsh, Powerlevel10k, plugins `zsh-autosuggestions` et `zsh-syntax-highlighting`, chacun depuis son dépôt GitHub officiel ;
  - fichiers versionnés **tels qu'ils existent aujourd'hui dans la WSL de développement** : `.zshrc`, `.commonrc` (POSIX, commun bash/zsh, `VAULT_ADDR` inclus — une URL, pas un secret), `.p10k.zsh` (généré par `p10k configure`), liés dans `~` ; `.zshrc` complété pour activer `fzf` et `zoxide` **seulement s'ils sont installés** (ils arrivent avec `cli-tools`) ;
  - `~/.bashrc` reste celui d'Ubuntu, complété d'une seule ligne qui charge un fichier versionné (`.commonrc` + complétion nvm + branche git dans l'invite, comme aujourd'hui) ;
  - zsh devient le shell de connexion (`chsh`).
- **`ROADMAP.md`** : `setup-socle` marqué fait ; ce change fixe le mécanisme de déploiement.

Hors périmètre : la police Nerd Font et le terminal (module `terminal`), `fzf`/`zoxide` eux-mêmes (`cli-tools`), nvm/Node (`node`) — `.commonrc` continue de charger nvm s'il est présent, sans l'installer.

## Capabilities

### New Capabilities
- `config-files` : déploiement des fichiers de configuration du dépôt vers `~` (liens symboliques, sauvegarde, vérification) et clonage idempotent de dépôts git — helpers du socle à la disposition de tous les modules.
- `module-shell` : le module `shell` — zsh, oh-my-zsh, Powerlevel10k, plugins, fichiers de config liés, shell de connexion.

### Modified Capabilities
_Aucune._

## Impact

- Nouveau `lib/files.sh` (chargé par `setup.sh`), `tests/test-files.sh`.
- Nouveau dossier `config/shell/` : `zshrc`, `commonrc`, `p10k.zsh`, `bashrc-extra.sh`.
- Nouveau `modules/20-shell.sh`, `tests/test-shell.sh` (doublures, sans réseau).
- Dans cette WSL, l'exécution du module remplace `~/.zshrc`, `~/.commonrc`, `~/.p10k.zsh` par des liens vers le dépôt (contenu identique, originaux en `.bak`).
- Dépôts externes (HTTPS, clone `--depth=1`) : `ohmyzsh/ohmyzsh`, `romkatv/powerlevel10k`, `zsh-users/zsh-autosuggestions`, `zsh-users/zsh-syntax-highlighting`.
