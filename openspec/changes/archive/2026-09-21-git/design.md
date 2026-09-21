## Context

Voir `proposal.md`. Le socle fournit `op_read` (échec explicite sans session, rien au journal), `op_session_active`, `pkg_installed`, `apt_add_repo` (clés `.asc` ou `.gpg`), `link_config`, `ensure_line`, `run`/`ui_spin`. Observé dans la WSL (18 sept 2026) : `~/.gitconfig` = identité + `init.defaultBranch`, clés `id_ed25519`/`id_rsa` déjà présentes, ni `delta` ni `gh`. Sur le laptop, l'agent 1Password sert « GitHub SSH Key (ED25519) » (vu en VM). Ubuntu 26.04 : `git-delta` 0.18 dans les dépôts ; `gh` 2.46 dans `universe`, plus récent sur le dépôt officiel GitHub.

## Goals / Non-Goals

**Goals :** convention de secrets simple et unique ; aucun secret sur disque quand l'agent suffit ; `module_check` qui constate tout ; testable hors ligne avec des doublures `op`/`gh`/`curl`.

**Non-Goals :** signature des commits ; hôtes autres que GitHub ; réglages git au-delà de l'identité, `delta` et la branche par défaut (le reste se met dans `~/.gitconfig.local` ou dans le fichier versionné, au fil de l'usage).

## Decisions

### D1. Convention des secrets : `op://Private/<Item>/<champ>`
Coffre `Private` (celui du compte), un item par service nommé comme dans 1Password (`GitHub SSH Key`), champs tels qu'affichés (`private key`, `public key`, `token`…). Les modules déclarent leurs références en constantes en tête de fichier (`GIT_SSH_KEY_REF="op://Private/GitHub SSH Key/private key?ssh-format=openssh"`) et ne lisent qu'à travers `op_read` dans une variable, jamais dans une sortie de commande journalisée. `?ssh-format=openssh` : sans ce paramètre, `op read` renvoie la clé privée au format PKCS#8 ; OpenSSH est le format attendu par `ssh`/`git`. Consigné dans `CLAUDE.md`.
Alternative rejetée : un coffre dédié « dotfiles » (une organisation de plus à maintenir, les items existent déjà dans `Private`).

### D2. Clé SSH : l'agent quand l'app est là, le fichier sinon
Critère : `pkg_installed 1password`. Avec l'app, `SSH_AUTH_SOCK` (posé par le module `1password` dans `.commonrc`) suffit — écrire la clé privée serait redondant et affaiblirait le modèle (la clé ne quitte pas 1Password). Sans app, `~/.ssh/id_ed25519` est écrit avec `umask 077` puis `chmod 600`, via une variable (`key=$(op_read "$ref") && printf '%s\n' "$key" >"$file"`) ; `~/.ssh` créé en 0700. Un fichier privé existant n'est **jamais** remplacé (la WSL a déjà ses clés) : `log_ok` « déjà présent ». La clé publique est écrite si absente, à partir de `…/public key`, puis `chmod 644` (sous `umask 077` elle naîtrait en 0600 ; la spec exige 0644).
Alternative rejetée : écrire `IdentityAgent` dans `~/.ssh/config` nous-mêmes — `SSH_AUTH_SOCK` global est déjà en place et couvre aussi `ssh-add -l` ; et observé en VM (18 sept 2026) : l'app 1Password écrit elle-même `Host *` / `IdentityAgent ~/.1password/agent.sock` dans `~/.ssh/config` à l'activation de l'agent, ce qui rend `ssh` fonctionnel même hors `.commonrc`.

### D3. `gh` depuis le dépôt officiel, connexion interactive
`apt_add_repo github-cli https://cli.github.com/packages/githubcli-archive-keyring.gpg https://cli.github.com/packages stable main` (clé binaire → `.gpg`, gérée par le helper ; architectures `dpkg --print-architecture`) puis `apt_install gh`. Connexion : `gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key` avec le terminal (stdin/stdout non redirigés : `gh` affiche un code à copier et ouvre le navigateur ; dans la WSL il affiche l'URL si aucun navigateur n'est joignable). Échec → échec du module (message : relancer `setup.sh git`). Le jeton est stocké par `gh` lui-même (`~/.config/gh/hosts.yml`) — pas dans le dépôt.
Alternatives : `gh` des dépôts Ubuntu (2.46, en retard sur les fonctionnalités) ; jeton depuis 1Password (refusé le 18 sept : pas de PAT à stocker).

### D4. Hôtes connus depuis `api.github.com/meta`
`curl -fsSL https://api.github.com/meta | jq -r '.ssh_keys[]'` (jq installé par `base`), capturé dans une variable (pas via `run` : la sortie JSON n'a rien à faire au journal, et l'erreur `curl` est journalisée par le module en cas d'échec), chaque ligne préfixée `github.com ` et ajoutée par `ensure_line` à `~/.ssh/known_hosts` (créé si absent, 0600). Vérification : `ssh-keygen -F github.com`. Source officielle, tous algorithmes, idempotent.
Alternative rejetée : `ssh-keyscan github.com` (pas d'authenticité : TOFU).

### D5. `gitconfig` versionné + `include` local
`config/git/gitconfig` = fichier actuel de la WSL + section `delta` (README de delta) + `[include] path = ~/.gitconfig.local` (git ignore silencieusement un include absent). Le lien remplace `~/.gitconfig` (original en `.bak`). Le courriel et le nom sont déjà publics dans l'historique du dépôt.

### D6. `module_check`
Vrai si : `gh` et `git-delta` installés ; lien `~/.gitconfig` en place ; `ssh-keygen -F github.com` trouve l'hôte ; clé : avec l'app, rien à vérifier ; sans app, `~/.ssh/id_ed25519` existe ; `gh auth token >/dev/null 2>&1` réussit (lecture locale de `~/.config/gh/hosts.yml`, **sans réseau** : `module_check` tourne à chaque `--list` et à l'ouverture du menu, `gh auth status` interrogerait l'API à chaque fois et passerait le module « à faire » hors ligne). `gh auth status` n'est appelé que dans `module_configure`, pour décider de lancer `gh auth login` ; un jeton révoqué y est donc rattrapé à la prochaine exécution du module.

### D7. Tests (`tests/test-git.sh`)
`HOME` isolé ; doublures : `dpkg-query` (paramétrable : app présente ou non), `op` (renvoie une fausse clé pour la référence attendue ; compte les lectures), `gh` (`auth status` selon un marqueur, `auth login` pose le marqueur), `curl` (renvoie un `meta` JSON factice), `jq` réel, `ssh-keygen` réel. Cas : app présente → aucune lecture `op`, aucun fichier ; sans app, clé absente → fichiers écrits, modes 600/644, valeur absente du journal ; sans app, clé présente → aucune lecture ; sans session → échec avec le message d'`op_read` ; hôtes connus idempotents ; `gh auth login` une fois puis plus jamais ; `module_check` après coup. Parcours réel : WSL (clé existante non touchée, `gh auth login` réel), VM (agent, `git clone git@github.com:…` en SSH).

## Risks / Trade-offs

- [`op read` de la clé privée demande une autorisation dans l'app / un déverrouillage] → sans app seulement (session CLI, déjà ouverte par le module `1password` dans le même run ; expirée → message clair).
- [`gh auth login --web` dans la WSL ne peut pas ouvrir de navigateur] → `gh` affiche l'URL et le code à saisir ; l'utilisateur ouvre le navigateur Windows. Étape interactive assumée (décision du 18 sept).
- [Le lien `~/.gitconfig` expose nom/courriel dans le dépôt public] → déjà publics via les commits.
- [`api.github.com` injoignable] → `known_hosts` non mis à jour, module en échec avec l'extrait du journal ; relancer.
- [`delta` absent au moment où git est lancé (ex. VM avant le module)] → `core.pager=delta` ferait échouer `git diff` ; le module installe `git-delta` **avant** de poser le lien.
