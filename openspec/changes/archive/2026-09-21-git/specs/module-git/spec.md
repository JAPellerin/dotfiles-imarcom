## Purpose

Rendre git prêt à l'emploi sur le poste : identité et préférences versionnées, affichage des diffs avec `delta`, CLI GitHub, clé SSH fournie par 1Password selon l'environnement et hôtes connus, sans jamais exposer un secret.

## ADDED Requirements

### Requirement: Configuration git versionnée
Le module `git` (groupe `dev`, dépend de `base` et `1password`, sans session graphique requise) SHALL déployer `config/git/gitconfig` vers `~/.gitconfig` par le helper de liens du socle. Ce fichier SHALL définir l'identité (`user.name`, `user.email`), `init.defaultBranch=main`, l'intégration de `delta` (`core.pager`, `interactive.diffFilter`, `delta.navigate`, `merge.conflictstyle=zdiff3`, `diff.colorMoved`) et inclure `~/.gitconfig.local` (facultatif, non versionné) pour les réglages propres à une machine. Le module SHALL installer `git-delta` depuis les dépôts Ubuntu.

#### Scenario: Déploiement
- **WHEN** le module se termine
- **THEN** `~/.gitconfig` est un lien vers le dépôt, `git config --get user.email` renvoie l'adresse versionnée, `git config --get core.pager` renvoie `delta` et `delta --version` fonctionne

#### Scenario: Réglage local
- **WHEN** `~/.gitconfig.local` définit `user.email` à une autre valeur
- **THEN** `git config --get user.email` renvoie cette valeur, sans modification du fichier versionné

### Requirement: CLI GitHub depuis le dépôt officiel
Le module SHALL ajouter le dépôt apt officiel de GitHub CLI (`cli.github.com/packages`, clé `githubcli-archive-keyring.gpg`) via le helper apt du socle et installer `gh`. Si `gh auth status` échoue, le module SHALL lancer `gh auth login` (hôte `github.com`, protocole git SSH, connexion par navigateur, sans envoi de clé SSH) en guidant l'utilisateur ; l'échec ou l'abandon de la connexion MUST faire échouer le module avec un message explicite. `module_check` SHALL considérer la connexion `gh` comme une condition du « déjà fait ».

#### Scenario: Première connexion
- **WHEN** `gh` vient d'être installé et l'utilisateur termine la connexion dans le navigateur
- **THEN** `gh auth status` réussit et le module continue

#### Scenario: Déjà connecté
- **WHEN** `gh auth status` réussit avant l'exécution
- **THEN** aucun `gh auth login` n'est lancé

### Requirement: Clé SSH selon l'environnement
La clé SSH GitHub SHALL être référencée par `op://Private/GitHub SSH Key/private key` (format OpenSSH) et `op://Private/GitHub SSH Key/public key`. Lorsque l'application 1Password est installée, le module MUST NOT écrire de clé privée sur le disque : l'agent 1Password la sert (`SSH_AUTH_SOCK`). Sinon, le module SHALL écrire `~/.ssh/id_ed25519` (mode 0600, dossier `~/.ssh` en 0700) et `~/.ssh/id_ed25519.pub` (0644) depuis 1Password **uniquement si le fichier privé n'existe pas** ; un fichier existant MUST être laissé intact et signalé. La valeur de la clé MUST NOT apparaître à l'écran ni dans le journal.

#### Scenario: Poste avec l'application
- **WHEN** le paquet `1password` est installé
- **THEN** aucun fichier `~/.ssh/id_ed25519` n'est créé et le module indique que l'agent 1Password sert la clé

#### Scenario: Sans application, clé absente
- **WHEN** `1password` n'est pas installé, une session `op` est active et `~/.ssh/id_ed25519` n'existe pas
- **THEN** les deux fichiers sont écrits avec les bons modes et `ssh-keygen -l -f ~/.ssh/id_ed25519.pub` affiche l'empreinte

#### Scenario: Sans application, clé présente
- **WHEN** `~/.ssh/id_ed25519` existe déjà
- **THEN** le module ne le modifie pas, ne lit pas le secret et le signale

#### Scenario: Sans session 1Password
- **WHEN** aucune session `op` n'est active et la clé doit être écrite
- **THEN** le module échoue avec le message du helper de lecture (lancer `setup.sh 1password`)

### Requirement: Hôtes connus
Le module SHALL ajouter à `~/.ssh/known_hosts` les clés publiques SSH de `github.com` publiées par GitHub (`api.github.com/meta`, champ `ssh_keys`), une ligne par clé, sans doublon d'une exécution à l'autre, et SHALL le vérifier avec `ssh-keygen -F github.com`.

#### Scenario: Ajout idempotent
- **WHEN** le module s'exécute deux fois
- **THEN** `known_hosts` contient chaque clé de GitHub une seule fois et `ssh-keygen -F github.com` trouve l'hôte
