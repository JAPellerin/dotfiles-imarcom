## MODIFIED Requirements

### Requirement: Installation depuis le dépôt officiel
Le module `1password` SHALL ajouter le dépôt apt officiel de 1Password (`downloads.1password.com/linux/debian/<arch>`, clé `1password.asc`) ainsi que la politique `debsig` documentée par 1Password, puis installer les paquets `1password-cli` et, si une session graphique est disponible, `1password`. Il SHALL dépendre de `base`. Il SHALL n'être marqué « déjà fait » que si le CLI est installé, l'application est installée quand une session graphique existe, le fragment de config shell de l'agent SSH est en place quand l'application est installée, et une session `op` est active.

#### Scenario: Poste graphique
- **WHEN** le module s'exécute sur le laptop (session graphique)
- **THEN** `1password` et `1password-cli` sont installés et `op --version` fonctionne

#### Scenario: Sans session graphique
- **WHEN** le module s'exécute dans WSL
- **THEN** seul `1password-cli` est installé, sans erreur, et le module signale que l'application de bureau a été omise

#### Scenario: Fragment de l'agent SSH retiré
- **WHEN** l'application de bureau est installée, une session `op` est active, mais le fragment de config shell de l'agent SSH n'est plus en place
- **THEN** le module n'est pas « déjà fait », et son exécution rétablit le fragment

### Requirement: Agent SSH
Lorsque l'application de bureau est installée, le module SHALL fournir `SSH_AUTH_SOCK` vers l'agent 1Password (`~/.1password/agent.sock`) par un fragment de configuration shell versionné dans le dépôt et lié dans `~/.commonrc.d/`, chargé par la configuration shell commune en bash comme en zsh. Le module MUST NOT ajouter de ligne à `~/.commonrc` ni à un autre fichier de configuration du shell : le résultat SHALL être le même quel que soit l'ordre d'exécution de `1password` et de `shell`. Sans application de bureau, aucun fragment n'est lié. L'activation de l'agent dans l'app SHALL être obtenue et vérifiée pendant le parcours de connexion (présence du socket) et MUST NOT être reportée en étape manuelle de fin d'exécution. Le module SHALL indiquer que la variable prend effet dans un nouveau terminal.

#### Scenario: Configuration de l'agent
- **WHEN** le module se termine sur le poste graphique
- **THEN** `~/.commonrc.d/1password.sh` est un lien vers le fragment du dépôt, un nouveau terminal a `SSH_AUTH_SOCK` pointant sur `~/.1password/agent.sock`, le socket existe et le résumé final ne contient aucune étape manuelle pour 1Password

#### Scenario: 1Password avant le module shell
- **WHEN** `1password` s'exécute sur un poste neuf, avant `shell`, puis `shell` remplace `~/.commonrc` par un lien vers le dépôt
- **THEN** `SSH_AUTH_SOCK` est défini dans un nouveau terminal, et ni `~/.commonrc` ni un fichier du dépôt n'a reçu de ligne ajoutée par `1password`

#### Scenario: Sans application de bureau
- **WHEN** le module s'exécute alors que l'application de bureau n'est pas installée
- **THEN** aucun fragment `~/.commonrc.d/1password.sh` n'est lié
