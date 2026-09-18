# module-base Specification

## Purpose

Fournir les paquets de base dont dépendent la plupart des autres modules (téléchargement, compilation, manipulation de JSON) et mettre le système à jour au départ.

## Requirements

### Requirement: Paquets de base
Le module `base` SHALL installer depuis les dépôts Ubuntu, s'ils sont absents : `curl`, `wget`, `git`, `ca-certificates`, `gnupg`, `build-essential`, `make`, `jq`, `unzip`, `apt-transport-https`, `software-properties-common`. Il SHALL n'avoir aucune dépendance et ne pas nécessiter de session graphique.

#### Scenario: Première application
- **WHEN** le module `base` s'exécute sur une machine fraîche
- **THEN** tous les paquets listés sont installés et `module_check` retourne ensuite 0

#### Scenario: Déjà appliqué
- **WHEN** tous les paquets listés sont déjà installés
- **THEN** `module_check` retourne 0 et le module est sauté

### Requirement: Mise à jour du système
Lors de sa première application, le module `base` SHALL exécuter `apt update` puis `apt upgrade` en mode non interactif avant d'installer les paquets, afin que la machine parte d'un état à jour.

#### Scenario: Système non à jour
- **WHEN** des mises à jour sont disponibles au moment de l'application du module
- **THEN** elles sont appliquées sans question interactive de `apt`
