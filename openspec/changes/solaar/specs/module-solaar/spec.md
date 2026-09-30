## Purpose

Installer Solaar, le gestionnaire des périphériques Logitech (souris, claviers, récepteurs), depuis les dépôts d'Ubuntu, pour que l'utilisateur puisse régler ses appareils sans outil de l'éditeur, qui n'existe pas sous Linux.

## ADDED Requirements

### Requirement: Solaar depuis les dépôts d'Ubuntu
Le module `solaar` (groupe `bureau`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `solaar` depuis les dépôts d'Ubuntu, sans question à l'utilisateur. L'accès aux récepteurs MUST passer par les droits de la session locale fournis par le paquet, sans groupe système supplémentaire ni réouverture de session. Un paquet déjà installé MUST NOT être réinstallé. Le module MUST NOT écrire de réglages de périphériques.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Solaar
- **THEN** le paquet `solaar` est installé et, à la session suivante, Solaar démarre de lui-même avec son icône dans la barre du haut

#### Scenario: Déjà installé
- **WHEN** le paquet `solaar` est installé
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté
