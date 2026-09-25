## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Connexion guidée
Après l'installation, le module SHALL lancer le parcours de connexion guidée du socle, sans secret : Spotify ouvert, consigne de se connecter par « Continuer avec Google » avec le compte Google personnel de l'utilisateur (identifiants remplis par l'extension 1Password du navigateur), puis attente de la connexion. La connexion SHALL être constatée, sans `sudo`, sans réseau et sans 1Password, dans les préférences du client, par la même sonde dans le parcours et dans `module_check`. Le module MUST NOT lire de secret dans 1Password pour Spotify. Si le parcours n'aboutit pas (« Passer », pas de session graphique), le module SHALL déclarer l'étape manuelle de se connecter à Spotify, MUST NOT échouer, et reste à faire.

#### Scenario: Connexion guidée réussie
- **WHEN** le module ouvre Spotify et que l'utilisateur se connecte par « Continuer avec Google »
- **THEN** la connexion est constatée, aucune étape manuelle n'est déclarée et `module_check` retourne 0

#### Scenario: Déjà connecté
- **WHEN** le module s'exécute alors que l'utilisateur est déjà connecté
- **THEN** Spotify n'est pas ouvert et aucune étape manuelle n'est déclarée

#### Scenario: Passer
- **WHEN** l'utilisateur passe l'étape de connexion
- **THEN** le résumé final demande de se connecter à Spotify et le module se termine sans erreur

## REMOVED Requirements

### Requirement: Connexion déclarée comme étape manuelle
**Reason**: Remplacée par la connexion guidée ; l'étape manuelle n'est plus déclarée que si le parcours n'aboutit pas.
**Migration**: Aucune ; sur un poste déjà connecté, `module_check` le constate et rien n'est refait.
