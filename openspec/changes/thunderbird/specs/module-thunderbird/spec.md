## Purpose

Installer Thunderbird, le client de courriel et d'agenda de l'utilisateur, depuis l'archive officielle de Mozilla, dans le dossier personnel de l'utilisateur pour que Thunderbird puisse se mettre à jour lui-même, avec une commande et un lanceur dans le menu des applications.

## ADDED Requirements

### Requirement: Thunderbird depuis l'archive officielle de Mozilla, dans le dossier personnel
Le module `thunderbird` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer la dernière version de Thunderbird en français à partir de l'archive officielle publiée par Mozilla, dans un dossier appartenant à l'utilisateur, sans `sudo`, de sorte que la mise à jour intégrée de Thunderbird puisse écrire dans son dossier d'installation. Le module MUST NOT installer le snap de Thunderbird ni le paquet de transition d'Ubuntu, ni un paquet d'une source non officielle. Une installation existante MUST NOT être retéléchargée ni écrasée. Un téléchargement ou une extraction en échec MUST faire échouer le module en le nommant, sans laisser de dossier d'installation incomplet.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Thunderbird
- **THEN** Thunderbird est installé dans le dossier personnel, appartient à l'utilisateur, et `thunderbird --version` répond

#### Scenario: Déjà installé
- **WHEN** Thunderbird est déjà installé à cet emplacement
- **THEN** rien n'est téléchargé et l'installation existante n'est pas modifiée

#### Scenario: Téléchargement en échec
- **WHEN** l'archive ne peut pas être téléchargée ou extraite
- **THEN** le module échoue en le nommant et aucun dossier d'installation partiel ne subsiste

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Commande et lanceur
Le module SHALL rendre la commande `thunderbird` disponible dans `~/.local/bin` et SHALL déposer dans `~/.local/share/applications` un lanceur tiré du fichier de bureau que publie Mozilla, dont la commande et l'icône désignent l'installation du dossier personnel. `module_check` SHALL constater la commande et le lanceur.

#### Scenario: Lanceur dans le menu
- **WHEN** le module se termine
- **THEN** Thunderbird apparaît dans le menu des applications avec son icône, et s'ouvre depuis ce menu

#### Scenario: Lanceur retiré
- **WHEN** le lanceur a été supprimé
- **THEN** `module_check` retourne 1 et le module le rétablit sans retélécharger Thunderbird

### Requirement: Comptes déclarés comme étape manuelle
Lorsque le module vient d'installer Thunderbird, il SHALL déclarer l'étape manuelle d'ajouter les comptes de courriel et les agendas Google dans Thunderbird. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe Thunderbird
- **THEN** le résumé final demande d'ajouter les comptes de courriel et les agendas Google
