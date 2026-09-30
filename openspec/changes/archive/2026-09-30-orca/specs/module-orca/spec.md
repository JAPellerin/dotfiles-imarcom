## Purpose

Installer Orca, l'environnement où l'utilisateur mène plusieurs agents de code en parallèle, depuis le paquet `.deb` officiel le plus récent publié par son éditeur, pour qu'un poste neuf l'ait dans son menu d'applications.

## ADDED Requirements

### Requirement: Orca depuis son .deb officiel le plus récent
Le module `orca` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `orca-ide` à partir du `.deb` amd64 publié par l'éditeur dans ses releases GitHub, en retenant la plus récente des releases publiées qui contient un tel `.deb`, par les helpers du socle (recherche de l'URL, puis installation d'un `.deb` depuis une URL). Un paquet `orca-ide` déjà installé MUST NOT être retéléchargé ni réinstallé. L'échec de la recherche ou du téléchargement MUST faire échouer le module en le nommant.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Orca
- **THEN** le paquet `orca-ide` est installé, le lanceur d'Orca est présent dans le menu des applications et Orca démarre

#### Scenario: Déjà installé
- **WHEN** le paquet `orca-ide` est installé
- **THEN** `module_check` retourne 0 et rien n'est téléchargé

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Profil AppArmor qui permet à Orca de démarrer
Le module SHALL déployer le profil AppArmor versionné dans le dépôt, qui autorise les espaces de noms utilisateur à l'exécutable d'Orca, dans `/etc/apparmor.d/` sous un nom que les scripts de maintenance du paquet ne suppriment pas, par le helper de fichiers système du socle, et SHALL le charger dans le noyau lorsqu'il vient de l'écrire. Une relance sans changement MUST NOT recharger le profil. Si le chargement échoue, le module MUST échouer et le profil MUST NOT être laissé en place. `module_check` SHALL constater que le profil déployé est identique à celui du dépôt.

#### Scenario: Premier lancement sous Ubuntu 26.04
- **WHEN** l'utilisateur ouvre Orca après le module, sur un système qui restreint les espaces de noms utilisateur non privilégiés
- **THEN** Orca démarre sans plantage

#### Scenario: Profil retiré ou différent
- **WHEN** le profil a été supprimé ou modifié
- **THEN** `module_check` retourne 1 et le module réécrit puis recharge la version du dépôt

#### Scenario: Mise à jour d'Orca
- **WHEN** le paquet `orca-ide` est mis à jour après le module
- **THEN** le profil déployé est toujours en place et `module_check` retourne 0

#### Scenario: Chargement en échec
- **WHEN** le noyau refuse le profil
- **THEN** le module échoue en le nommant et le profil est retiré

### Requirement: Ajout des dépôts déclaré comme étape manuelle
Lorsque le module vient d'installer Orca, il SHALL déclarer l'étape manuelle d'ouvrir Orca et d'y ajouter ses dépôts de travail. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe Orca
- **THEN** le résumé final demande d'ouvrir Orca et d'y ajouter ses dépôts

#### Scenario: Installation en échec
- **WHEN** l'installation du paquet échoue
- **THEN** aucune étape manuelle n'est déclarée à ce titre
