# module-spotify Specification

## Purpose

Installer le client Spotify depuis le dépôt apt officiel de Spotify, pour qu'un poste neuf l'ait dans son menu d'applications et le reçoive ensuite par les mises à jour apt, sans laisser le paquet déclarer un second dépôt.

## Requirements

### Requirement: Spotify depuis le dépôt apt de l'éditeur, sans dépôt en double
Le module `spotify` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `spotify-client` depuis le dépôt apt officiel de Spotify, déclaré au format deb822 avec sa clé dans `/etc/apt/keyrings/` par le helper du socle. Avant l'installation, le module SHALL poser `/etc/apt/sources.list.d/spotify.list` sans aucune entrée de dépôt, ce qui empêche le paquet d'y déclarer lui-même le dépôt, de sorte qu'une seule déclaration de ce dépôt existe après installation comme après mise à jour. Le snap et le flatpak de Spotify MUST NOT être utilisés. Une réexécution MUST NOT réécrire ce fichier, la clé ni la déclaration du dépôt s'ils n'ont pas changé.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Spotify
- **THEN** `spotify-client` est installé depuis le dépôt de Spotify, une seule déclaration active de ce dépôt existe dans les sources apt, `apt update` réussit, et le lanceur de Spotify est présent dans le menu des applications

#### Scenario: Réexécution
- **WHEN** Spotify est installé et le dépôt déclaré
- **THEN** ni `spotify.list`, ni la clé, ni la déclaration du dépôt ne sont réécrits

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Connexion déclarée comme étape manuelle
Lorsque le module vient d'installer Spotify, il SHALL déclarer l'étape manuelle de se connecter à Spotify. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe Spotify
- **THEN** le résumé final demande de se connecter à Spotify

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si le paquet `spotify-client` est installé et que `/etc/apt/sources.list.d/spotify.list` est en place avec le contenu versionné. Le constat MUST NOT nécessiter `sudo` ni le réseau.

#### Scenario: Déjà installé
- **WHEN** `spotify-client` est installé et `spotify.list` en place
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Fichier anti-doublon retiré
- **WHEN** `/etc/apt/sources.list.d/spotify.list` a été supprimé ou modifié
- **THEN** `module_check` retourne 1 et le module le rétablit
