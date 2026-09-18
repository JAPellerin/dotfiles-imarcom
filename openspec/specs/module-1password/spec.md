# module-1password Specification

## Purpose

Installer 1Password (application de bureau et CLI `op`) selon la procédure officielle, connecter l'utilisateur et rendre les secrets du coffre disponibles aux autres modules, qui n'ont ainsi jamais de secret dans le dépôt.

## Requirements

### Requirement: Installation depuis le dépôt officiel
Le module `1password` SHALL ajouter le dépôt apt officiel de 1Password (`downloads.1password.com/linux/debian/<arch>`, clé `1password.asc`) ainsi que la politique `debsig` documentée par 1Password, puis installer les paquets `1password-cli` et, si une session graphique est disponible, `1password`. Il SHALL dépendre de `base`. Il SHALL n'être marqué « déjà fait » que si le CLI est installé, l'application est installée quand une session graphique existe, et une session `op` est active.

#### Scenario: Poste graphique
- **WHEN** le module s'exécute sur le laptop (session graphique)
- **THEN** `1password` et `1password-cli` sont installés et `op --version` fonctionne

#### Scenario: Sans session graphique
- **WHEN** le module s'exécute dans WSL
- **THEN** seul `1password-cli` est installé, sans erreur, et le module signale que l'application de bureau a été omise

### Requirement: Connexion de l'utilisateur
Après l'installation, le module SHALL vérifier si une session `op` est active (`op whoami`). Sinon, il SHALL guider l'utilisateur pour se connecter : d'abord via l'intégration avec l'application de bureau si elle est installée (l'utilisateur active « Integrate with 1Password CLI » puis confirme), sinon via `op account add` (adresse du compte, courriel, clé secrète, mot de passe saisis par l'utilisateur, jamais stockés par le script). Le module MUST échouer si aucune session n'est active à la fin.

#### Scenario: Intégration avec l'app
- **WHEN** l'application de bureau est installée et l'utilisateur confirme avoir activé l'intégration CLI
- **THEN** `op whoami` réussit et le module se termine avec succès

#### Scenario: Connexion manuelle
- **WHEN** l'application de bureau n'est pas installée
- **THEN** le module lance `op account add` puis `op signin`, et exporte la session pour la suite de l'exécution du runner

#### Scenario: Refus de connexion
- **WHEN** l'utilisateur interrompt la connexion
- **THEN** le module échoue avec un message expliquant que les modules qui ont besoin de secrets seront sautés

### Requirement: Helper de lecture de secret
Le socle SHALL fournir un helper qui lit un secret par référence `op://<coffre>/<item>/<champ>` et le renvoie sur la sortie standard, sans jamais l'écrire dans le journal. Si aucune session `op` n'est active, le helper MUST échouer avec un message explicite plutôt que de renvoyer une valeur vide.

#### Scenario: Lecture réussie
- **WHEN** un module demande `op://Perso/GitHub/token` avec une session active
- **THEN** la valeur est renvoyée et n'apparaît ni à l'écran ni dans le fichier journal

#### Scenario: Session absente
- **WHEN** un module demande un secret sans session `op` active
- **THEN** le helper échoue avec un code non nul et un message indiquant de lancer `setup.sh 1password`

### Requirement: Agent SSH
Lorsque l'application de bureau est installée, le module SHALL configurer `SSH_AUTH_SOCK` vers l'agent 1Password (`~/.1password/agent.sock`) dans la configuration shell commune, de façon idempotente, et SHALL déclarer l'étape manuelle « activer l'agent SSH dans 1Password (Settings > Developer > Use the SSH agent) ».

#### Scenario: Configuration de l'agent
- **WHEN** le module se termine sur le poste graphique
- **THEN** la ligne `SSH_AUTH_SOCK` est présente une seule fois dans la config shell commune et l'étape manuelle figure dans le résumé final
