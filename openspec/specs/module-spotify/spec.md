# module-spotify Specification

## Purpose

Installer le client Spotify depuis le dépôt apt officiel de Spotify, pour qu'un poste neuf l'ait dans son menu d'applications et le reçoive ensuite par les mises à jour apt, sans laisser le paquet déclarer un second dépôt, puis y connecter l'utilisateur par un parcours guidé, sans secret, par le code QR que le client affiche : le module n'est « déjà fait » qu'une fois l'utilisateur connecté.

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

### Requirement: Connexion guidée
Après l'installation, le module SHALL lancer le parcours de connexion guidée du socle, sans secret : Spotify ouvert, consigne de se connecter par le code QR que le client affiche, à scanner avec le téléphone de l'utilisateur, puis attente de la connexion. La connexion SHALL être constatée, sans `sudo`, sans réseau et sans 1Password, dans les préférences du client, par la même sonde dans le parcours et dans `module_check`. Le module MUST NOT lire de secret dans 1Password pour Spotify. Si le parcours n'aboutit pas (« Passer »), le module SHALL déclarer l'étape manuelle de se connecter à Spotify, MUST NOT échouer, et reste à faire.

#### Scenario: Connexion guidée réussie
- **WHEN** le module ouvre Spotify et que l'utilisateur scanne le code QR avec son téléphone
- **THEN** la connexion est constatée, aucune étape manuelle n'est déclarée et `module_check` retourne 0

#### Scenario: Déjà connecté
- **WHEN** le module s'exécute alors que l'utilisateur est déjà connecté
- **THEN** Spotify n'est pas ouvert et aucune étape manuelle n'est déclarée

#### Scenario: Passer
- **WHEN** l'utilisateur passe l'étape de connexion
- **THEN** le résumé final demande de se connecter à Spotify et le module se termine sans erreur

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si le paquet `spotify-client` est installé, que `/etc/apt/sources.list.d/spotify.list` est en place avec le contenu versionné, et que l'utilisateur est connecté au client Spotify. Le constat MUST NOT nécessiter `sudo`, le réseau ni 1Password.

#### Scenario: Déjà installé
- **WHEN** `spotify-client` est installé, `spotify.list` en place et l'utilisateur connecté
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Installé, pas encore connecté
- **WHEN** `spotify-client` est installé et `spotify.list` en place, mais l'utilisateur n'est pas connecté
- **THEN** `module_check` retourne 1 et une relance propose la connexion guidée sans réinstaller le paquet

#### Scenario: Fichier anti-doublon retiré
- **WHEN** `/etc/apt/sources.list.d/spotify.list` a été supprimé ou modifié
- **THEN** `module_check` retourne 1 et le module le rétablit
