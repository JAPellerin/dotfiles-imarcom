## Why

Après le shell, `git` est le premier module qui a besoin d'un **secret** (la clé SSH) : il fixe la convention de lecture des secrets dans 1Password — `op://<coffre>/<item>/<champ>`, coffre `Private` — que `vpn`, `projets` et les suivants réutiliseront. Il rend aussi le poste capable de cloner et pousser dès le premier démarrage (identité, `delta`, `gh`, hôtes connus).

## What Changes

- **Module `git`** (`modules/30-git.sh`, groupe `dev`, dépend de `base` et `1password`) :
  - `~/.gitconfig` versionné (`config/git/gitconfig`, lié par `link_config`) : identité (nom, courriel), `init.defaultBranch=main`, pager et diff via `delta` (`core.pager`, `interactive.diffFilter`, `delta.navigate`, `merge.conflictstyle=zdiff3`, `diff.colorMoved`), et `[include] path = ~/.gitconfig.local` pour d'éventuels réglages propres à une machine (non versionnés) ;
  - `git-delta` (dépôts Ubuntu) et **`gh`** depuis le dépôt apt officiel de GitHub (clé `githubcli-archive-keyring.gpg`, `cli.github.com/packages stable main`) ;
  - **clé SSH** : convention `op://Private/GitHub SSH Key/private key` et `…/public key`. Quand l'application 1Password est installée, rien n'est écrit : l'agent 1Password sert la clé (`SSH_AUTH_SOCK`, module `1password`). Sans app (WSL, session sans GUI), le module écrit `~/.ssh/id_ed25519` (0600) et `~/.ssh/id_ed25519.pub` depuis 1Password **seulement s'ils n'existent pas** — jamais d'écrasement, jamais de trace dans le journal ;
  - **hôtes connus** : clés SSH de `github.com` ajoutées à `~/.ssh/known_hosts` depuis la source officielle (`api.github.com/meta`), sans doublon ;
  - **`gh auth login`** interactif (navigateur, protocole SSH, sans envoi de clé) si `gh auth status` échoue ; état constaté par `gh auth status`.
- **Convention des secrets** consignée dans `CLAUDE.md` : coffre `Private`, un item par service, champs nommés comme dans 1Password ; les modules passent par `op_read`, jamais par `op` direct ; aucune valeur n'est journalisée.

Hors périmètre : signature des commits (refusée le 18 sept 2026), clés d'autres hôtes (Bitbucket : module `projets`), `lazygit` et autres outils (`cli-tools`).

## Capabilities

### New Capabilities
- `module-git` : le module `git` — configuration versionnée, `delta`, `gh`, clé SSH depuis 1Password selon l'environnement, hôtes connus, connexion `gh`.

### Modified Capabilities
_Aucune._

## Impact

- Nouveau `modules/30-git.sh`, `config/git/gitconfig`, `tests/test-git.sh` (doublures `op`, `gh`, `dpkg-query`, `curl`).
- Dans la WSL : `~/.gitconfig` devient un lien (original en `.bak`, contenu repris) ; les clés existantes dans `~/.ssh` ne sont pas touchées.
- Dépôt apt tiers : `https://cli.github.com/packages` (clé binaire `.gpg`, gérée par `apt_add_repo`).
- Réseau : `api.github.com/meta` (hôtes connus), `gh auth login` (navigateur).
- Docs : `CLAUDE.md` (convention `op://`), `ROADMAP.md` (`git` fait ; `git-delta` installé ici, `cli-tools` le trouvera déjà présent).
