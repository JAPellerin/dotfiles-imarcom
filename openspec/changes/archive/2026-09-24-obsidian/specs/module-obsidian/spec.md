## Purpose

Installer Obsidian, l'outil de notes de l'utilisateur, depuis le paquet `.deb` officiel le plus récent publié par son éditeur, pour qu'un poste neuf l'ait dans son menu d'applications.

## ADDED Requirements

### Requirement: Obsidian depuis son .deb officiel le plus récent
Le module `obsidian` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `obsidian` à partir du `.deb` amd64 publié par l'éditeur dans ses releases GitHub, en retenant la plus récente des releases publiées qui contient un tel `.deb`, par les helpers du socle (recherche de l'URL, puis installation d'un `.deb` depuis une URL). Un paquet `obsidian` déjà installé MUST NOT être retéléchargé ni réinstallé. L'échec de la recherche ou du téléchargement MUST faire échouer le module en le nommant.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Obsidian
- **THEN** le paquet `obsidian` est installé et le lanceur d'Obsidian est présent dans le menu des applications

#### Scenario: Dernière release sans .deb
- **WHEN** la release la plus récente de l'éditeur ne contient pas de `.deb` amd64
- **THEN** le `.deb` de la dernière release qui en contient un est installé

#### Scenario: Déjà installé
- **WHEN** le paquet `obsidian` est installé
- **THEN** `module_check` retourne 0 et rien n'est téléchargé

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Ouverture du coffre déclarée comme étape manuelle
Lorsque le module vient d'installer Obsidian, il SHALL déclarer l'étape manuelle d'ouvrir Obsidian et d'ouvrir ou de synchroniser son coffre de notes. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe Obsidian
- **THEN** le résumé final demande d'ouvrir Obsidian et son coffre

#### Scenario: Installation en échec
- **WHEN** l'installation du paquet échoue
- **THEN** aucune étape manuelle n'est déclarée à ce titre
