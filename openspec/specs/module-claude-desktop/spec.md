# module-claude-desktop Specification

## Purpose

Installer l'application Claude Desktop depuis le dépôt apt d'Anthropic, prête à l'emploi y compris pour Cowork, sans laisser le paquet déclarer un second dépôt, et signaler à l'utilisateur les gestes qui restent les siens.

## Requirements

### Requirement: Claude Desktop depuis le dépôt apt d'Anthropic, sans dépôt en double
Le module `claude-desktop` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `claude-desktop` depuis le dépôt apt d'Anthropic, déclaré au format deb822 avec sa clé dans `/etc/apt/keyrings/` par le helper du socle, en laissant apt installer les paquets recommandés. Avant l'installation, le module SHALL désactiver l'enregistrement du dépôt par le paquet lui-même, par le réglage que documente Anthropic, de sorte qu'une seule déclaration de ce dépôt existe après installation comme après mise à jour.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Claude Desktop
- **THEN** le lanceur de Claude est présent dans le menu des applications, et une seule déclaration du dépôt d'Anthropic existe dans les sources apt

#### Scenario: Réexécution
- **WHEN** l'application est installée et le dépôt déclaré
- **THEN** ni le réglage, ni la clé, ni la déclaration du dépôt ne sont réécrits

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Cowork préparé
Le module SHALL inscrire l'utilisateur courant dans le groupe `kvm`, que la documentation de Claude Desktop exige pour Cowork, par le helper d'appartenance aux groupes du socle, et SHALL déclarer l'étape de réouverture de session tant que la session courante ne porte pas ce groupe. L'absence de virtualisation matérielle sur la machine MUST NOT faire échouer le module.

#### Scenario: Utilisateur inscrit
- **WHEN** le module se termine
- **THEN** la base des groupes du système liste l'utilisateur parmi les membres de `kvm`

#### Scenario: Session à rouvrir
- **WHEN** l'utilisateur vient d'être inscrit au groupe `kvm`
- **THEN** le résumé final demande de rouvrir la session en nommant le groupe `kvm`

#### Scenario: Machine sans virtualisation matérielle
- **WHEN** `/dev/kvm` n'existe pas sur la machine
- **THEN** le module se termine sans erreur

### Requirement: Connexion déclarée comme étape manuelle
Lorsque le module vient d'installer l'application, il SHALL déclarer l'étape manuelle d'ouvrir Claude et de se connecter avec le compte Anthropic. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe l'application
- **THEN** le résumé final demande d'ouvrir Claude et de se connecter

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si le paquet `claude-desktop` est installé, que le réglage empêchant le paquet de déclarer son dépôt est en place avec le contenu attendu, et que l'utilisateur est membre du groupe `kvm` dans la base des groupes. Le constat MUST NOT nécessiter `sudo` ni le réseau.

#### Scenario: Poste complet
- **WHEN** tout est en place
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Réglage retiré
- **WHEN** `/etc/default/claude-desktop` a été supprimé
- **THEN** `module_check` retourne 1 et le module le rétablit
