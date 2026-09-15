## Why

Le poste de travail Ubuntu 26.04 (nouveau laptop à venir) doit pouvoir être configuré de zéro, de façon reproductible et avec le moins d'étapes manuelles possible. Le précédent script (`~/setup-sudo.sh`, septembre 2026) était monolithique, root-only et sans interactivité ; avant d'ajouter des modules, il faut un socle solide : bootstrap en une ligne, CLI interactive, contrat de module et accès aux secrets via 1Password.

## What Changes

- **Bootstrap en une ligne** : `bootstrap.sh` lancé par `curl | bash` installe `git` et `gum`, clone le dépôt public en HTTPS dans `~/dotfiles` et enchaîne sur `setup.sh`.
- **Runner `setup.sh`** : point d'entrée unique. Sans argument, menu interactif `gum` listant les modules par groupe (`[shell] zsh …`) avec leur état, les modules non faits présélectionnés ; avec argument, exécution d'un ou plusieurs modules par nom (`setup.sh git node`), plus `--all`, `--list`. Tourne en utilisateur, demande `sudo` une seule fois (keepalive). Résumé final : fait / sauté / échoué + étapes manuelles restantes.
- **Contrat de module** : un fichier par module dans `modules/`, déclarant `MODULE_NAME`, `MODULE_DESC`, `MODULE_GROUP`, `MODULE_DEPS` et les fonctions `module_check`, `module_install`, `module_configure`. Le runner résout les dépendances et saute ce qui est déjà fait (idempotence).
- **Bibliothèque `lib/`** : journalisation, `sudo`, helpers apt (dépôt deb822 + clé dans `/etc/apt/keyrings/`), wrappers `gum`, détection d'environnement graphique (tolérance WSL), helpers 1Password (`op read`).
- **Module `base`** : paquets de départ (`curl`, `git`, `ca-certificates`, `build-essential`, `jq`, `make`, ...).
- **Module `1password`** : app de bureau + CLI `op` depuis le dépôt apt officiel de 1Password, connexion de l'utilisateur, vérification de session ; exécuté d'office en premier car les autres modules en dépendent pour leurs secrets.
- **`CLAUDE.md`** à jour des décisions de conception et **`ROADMAP.md`** (découpage des modules et ordre des changes, 15 sept 2026).

Hors périmètre de ce change : tous les autres modules (shell, git, node, docker, navigateurs, éditeurs, apps, GNOME), la gestion des AppImages, la gestion des fichiers de config (symlinks / stow / chezmoi), la VM de test. Chacun fera l'objet de son propre change une fois le socle éprouvé.

## Capabilities

### New Capabilities
- `bootstrap` : installation en une ligne sur une machine vierge (prérequis, clone, lancement de `setup.sh`).
- `setup-runner` : CLI interactive `setup.sh` — menu, exécution ciblée, gestion de `sudo`, résolution des dépendances, résumé et étapes manuelles.
- `module-contract` : forme obligatoire d'un module (métadonnées, fonctions `check`/`install`/`configure`, idempotence, dépendances).
- `module-base` : module des paquets de base.
- `module-1password` : installation de 1Password (app + CLI), connexion et mise à disposition des secrets aux autres modules.

### Modified Capabilities
_Aucune : le dépôt part de zéro._

## Impact

- Nouveaux fichiers : `bootstrap.sh`, `setup.sh`, `lib/*.sh`, `modules/00-base.sh`, `modules/10-1password.sh` ; `CLAUDE.md` et `ROADMAP.md` à jour.
- Dépendances système : `gum` (dépôt Ubuntu 26.04), dépôt apt 1Password (`downloads.1password.com`), `sudo`.
- Dépôt public sur GitHub `JAPellerin/dotfiles-imarcom` (Bitbucket écarté : pas de workspace personnel possible avec le compte Imarcom) : l'URL raw de `bootstrap.sh` (`https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh`) et l'URL de clone HTTPS (`https://github.com/JAPellerin/dotfiles-imarcom.git`) sont des constantes du bootstrap.
- Les modules futurs dépendront du contrat défini ici : toute modification ultérieure du contrat devra passer par un change.
