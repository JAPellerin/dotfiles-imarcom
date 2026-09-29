## MODIFIED Requirements

### Requirement: Clé SSH selon l'environnement
La clé SSH git (GitHub et Bitbucket) SHALL être référencée par `op://Private/Git SSH Key/private key` (format OpenSSH) et `op://Private/Git SSH Key/public key`. Lorsque l'application 1Password est installée, le module MUST NOT écrire de clé privée sur le disque : l'agent 1Password la sert (`SSH_AUTH_SOCK`). Sinon, le module SHALL écrire `~/.ssh/id_ed25519` (mode 0600, dossier `~/.ssh` en 0700) et `~/.ssh/id_ed25519.pub` (0644) depuis 1Password **uniquement si le fichier privé n'existe pas** ; un fichier existant MUST être laissé intact et signalé. La valeur de la clé MUST NOT apparaître à l'écran ni dans le journal.

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
