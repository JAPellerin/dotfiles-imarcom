## Purpose

Installer le client Spotify depuis le dépôt apt officiel de Spotify, pour qu'un poste neuf l'ait dans son menu d'applications et le reçoive ensuite par les mises à jour apt.

## ADDED Requirements

### Requirement: Spotify depuis le dépôt apt de l'éditeur
Le module `spotify` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `spotify-client` depuis le dépôt apt officiel de Spotify, déclaré au format deb822 avec sa clé dans `/etc/apt/keyrings/` par le helper du socle. Le snap et le flatpak de Spotify MUST NOT être utilisés. Une réexécution MUST NOT réécrire la clé ni la déclaration du dépôt si elles n'ont pas changé.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Spotify
- **THEN** `spotify-client` est installé depuis le dépôt de Spotify, une seule déclaration de ce dépôt existe, et le lanceur de Spotify est présent dans le menu des applications

#### Scenario: Déjà installé
- **WHEN** `spotify-client` est installé
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Connexion déclarée comme étape manuelle
Lorsque le module vient d'installer Spotify, il SHALL déclarer l'étape manuelle de se connecter à Spotify. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe Spotify
- **THEN** le résumé final demande de se connecter à Spotify
