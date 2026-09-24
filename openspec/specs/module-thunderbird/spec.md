# module-thunderbird Specification

## Purpose

Installer Thunderbird, le client de courriel et d'agenda de l'utilisateur, depuis l'archive officielle de Mozilla, dans la langue d'Ubuntu, dans le dossier personnel de l'utilisateur pour que Thunderbird puisse se mettre à jour lui-même, avec une commande, un lanceur dans le menu des applications et les dictionnaires anglais (Canada) et français.

## Requirements

### Requirement: Thunderbird depuis l'archive officielle de Mozilla, dans le dossier personnel
Le module `thunderbird` (groupe `apps`, dépend de `base` et de `shell`, nécessite une session graphique) SHALL installer la dernière version de Thunderbird dans la langue d'Ubuntu à partir de l'archive officielle publiée par Mozilla, dans un dossier appartenant à l'utilisateur, sans `sudo`, de sorte que la mise à jour intégrée de Thunderbird puisse écrire dans son dossier d'installation. Le module MUST NOT installer le snap de Thunderbird ni le paquet de transition d'Ubuntu, ni un paquet d'une source non officielle. Une installation existante dans la langue d'Ubuntu MUST NOT être retéléchargée ni écrasée. Un téléchargement ou une extraction en échec MUST faire échouer le module en le nommant, sans laisser de dossier d'installation incomplet.

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

### Requirement: Langue d'Ubuntu
Le module SHALL retenir la langue de Thunderbird d'après celle d'Ubuntu : la variante régionale si Mozilla la publie, sinon la langue sans région, sinon l'anglais (États-Unis). `module_check` SHALL constater, sans réseau, que la langue de l'installation est celle retenue. Une installation dans une autre langue SHALL être remplacée par la version de la langue retenue sans toucher au profil de l'utilisateur. Une archive dont la langue n'est pas celle demandée MUST faire échouer le module en le nommant, sans remplacer l'installation existante.

#### Scenario: Ubuntu en français du Canada
- **WHEN** Ubuntu est en `fr_CA.UTF-8`
- **THEN** le module installe la version française de Thunderbird (Mozilla ne publie pas de `fr-CA`)

#### Scenario: Ubuntu en anglais
- **WHEN** Ubuntu est en `en_CA.UTF-8` ou en `en_US.UTF-8`
- **THEN** le module installe respectivement la version `en-CA` ou `en-US`

#### Scenario: Langue d'Ubuntu changée
- **WHEN** Thunderbird est installé dans une autre langue que celle d'Ubuntu
- **THEN** `module_check` retourne 1, le module réinstalle Thunderbird dans la langue d'Ubuntu et le profil de l'utilisateur est intact

#### Scenario: Archive dans une autre langue
- **WHEN** l'archive téléchargée n'est pas dans la langue demandée
- **THEN** le module échoue en le nommant et l'installation existante est conservée

### Requirement: Dictionnaires anglais (Canada) et français
Le module SHALL déployer la stratégie d'entreprise versionnée dans le dépôt, qui fait installer d'office par Thunderbird les dictionnaires anglais (Canada) et français (Dicollecte) depuis addons.thunderbird.net sans empêcher l'utilisateur de les désactiver, dans le dossier système des stratégies de Thunderbird, par le helper de fichiers système du socle. `module_check` SHALL constater que la stratégie déployée est identique à celle du dépôt. Une relance sans changement MUST NOT appeler `sudo`.

#### Scenario: Premier démarrage
- **WHEN** l'utilisateur ouvre Thunderbird après le module
- **THEN** les dictionnaires anglais (Canada) et français sont installés et proposés pour la vérification orthographique

#### Scenario: Stratégie retirée ou différente
- **WHEN** la stratégie a été supprimée ou modifiée
- **THEN** `module_check` retourne 1 et le module la réécrit

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
