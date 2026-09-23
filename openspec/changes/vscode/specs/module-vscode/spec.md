## Purpose

Installer VS Code depuis le dépôt apt de Microsoft, avec le trousseau où il range ses jetons et les extensions de l'utilisateur tirées d'une liste versionnée, pour qu'un poste neuf ait l'éditeur prêt à l'emploi.

## ADDED Requirements

### Requirement: VS Code depuis le dépôt de Microsoft, sans dépôt en double
Le module `vscode` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `code` depuis le dépôt apt de Microsoft, déclaré au format deb822 avec sa clé dans `/etc/apt/keyrings/` par le helper du socle. Le module SHALL empêcher le paquet d'enregistrer lui-même un second dépôt Microsoft, de sorte qu'après installation une seule déclaration de ce dépôt existe et qu'une réexécution ne la réécrive pas. Le module SHALL aussi installer `gnome-keyring`.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans VS Code
- **THEN** `code --version` répond, le lanceur de VS Code est présent dans le menu des applications, et une seule déclaration du dépôt Microsoft existe dans les sources apt

#### Scenario: Réexécution
- **WHEN** VS Code est installé et le dépôt déclaré
- **THEN** ni la clé ni la déclaration du dépôt ne sont réécrites

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Extensions tirées d'une liste versionnée
Le module SHALL installer dans VS Code chaque extension listée dans `config/vscode/extensions.txt` (un identifiant par ligne ; lignes vides et commentaires ignorés) qui n'est pas déjà installée, sans distinction de casse. Une extension installée qui ne figure pas dans la liste MUST être laissée en place. L'échec d'installation d'une extension MUST faire échouer le module en la nommant.

#### Scenario: Première installation
- **WHEN** le module s'exécute et qu'aucune extension de la liste n'est installée
- **THEN** toutes les extensions de la liste sont installées

#### Scenario: Extensions partiellement présentes
- **WHEN** une partie des extensions de la liste est déjà installée
- **THEN** seules les manquantes sont installées

#### Scenario: Extension hors liste
- **WHEN** une extension installée à la main n'est pas dans la liste
- **THEN** elle reste installée

#### Scenario: Extension introuvable
- **WHEN** l'installation d'une extension de la liste échoue
- **THEN** le module échoue en nommant l'extension

### Requirement: Connexion à Jira et Bitbucket déclarée comme étape manuelle
Lorsque le module vient d'installer VS Code, il SHALL déclarer l'étape manuelle de se connecter à Jira et à Bitbucket dans l'extension Atlassian. Le module MUST NOT tenter d'établir lui-même ces connexions, qui passent par une autorisation dans le navigateur et un stockage de secrets propre à VS Code. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe VS Code
- **THEN** le résumé final demande de se connecter à Jira et à Bitbucket dans l'extension Atlassian

#### Scenario: VS Code déjà installé
- **WHEN** le module s'exécute alors que VS Code était déjà installé (par exemple pour ajouter une extension de la liste)
- **THEN** aucune étape de connexion n'est déclarée

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si `code` et `gnome-keyring` sont installés et que chaque extension de la liste est installée. Le constat MUST NOT nécessiter `sudo`.

#### Scenario: Poste complet
- **WHEN** tout est en place
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Extension ajoutée à la liste
- **WHEN** un identifiant est ajouté à `config/vscode/extensions.txt` et n'est pas installé
- **THEN** `module_check` retourne 1 et le module installe cette seule extension
