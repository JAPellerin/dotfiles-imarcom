## Purpose

Doter le poste de Node.js par nvm, avec la version LTS du moment et la version 26 utilisée par les projets, pnpm 11 sous chacune, et les outils npm globaux dont le poste a besoin, sans modifier les fichiers de configuration du shell que gère le module `shell`.

## ADDED Requirements

### Requirement: nvm installé selon sa méthode git
Le module `node` (groupe `dev`, dépend de `base` et de `shell`, sans session graphique requise) SHALL installer nvm dans `~/.nvm` en clonant son dépôt officiel à une étiquette de version fixée par le module. Le module MUST NOT exécuter le script d'installation de nvm ni modifier un fichier de configuration du shell : le chargement de nvm est assuré par la configuration commune du module `shell`. Un clone existant depuis la même origine MUST être conservé tel quel ; un dossier `~/.nvm` qui n'est pas ce clone MUST faire échouer le module en le nommant, sans rien modifier.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans `~/.nvm`
- **THEN** `~/.nvm` est un clone du dépôt de nvm à l'étiquette fixée, et `nvm` est disponible dans un nouveau shell sans qu'aucun fichier du shell n'ait été modifié

#### Scenario: nvm déjà installé
- **WHEN** `~/.nvm` est déjà un clone du dépôt de nvm, même à une autre version
- **THEN** il n'est ni recloné ni mis à jour

#### Scenario: Dossier étranger
- **WHEN** `~/.nvm` existe mais n'est pas un clone du dépôt de nvm
- **THEN** le module échoue en nommant le dossier et ne le modifie pas

### Requirement: Node LTS et Node 26, la 26 par défaut
Le module SHALL installer par nvm la version LTS courante de Node et la version majeure 26, puis faire de la 26 la version par défaut des nouveaux shells. Lorsque la LTS courante est elle-même une version 26, une seule version SHALL être installée. Une version déjà installée MUST NOT être réinstallée.

#### Scenario: Deux versions distinctes
- **WHEN** le module s'exécute alors que la LTS courante n'est pas une version 26
- **THEN** la LTS et une version 26 sont installées, et un nouveau shell utilise la 26

#### Scenario: LTS devenue la 26
- **WHEN** la LTS courante est une version 26
- **THEN** une seule version est installée, et elle est la version par défaut

#### Scenario: Déjà en place
- **WHEN** la LTS et la 26 sont installées et la 26 est la version par défaut
- **THEN** aucune version n'est téléchargée ni réinstallée

### Requirement: pnpm 11 sous chaque version, openspec sous la 26
Le module SHALL installer pnpm en version majeure 11 comme outil global sous la LTS et sous la 26, et `openspec` comme outil global sous la 26 seulement. Un outil déjà présent à la bonne version majeure MUST NOT être réinstallé ; un pnpm d'une autre version majeure SHALL être remplacé par la 11.

#### Scenario: Outils installés
- **WHEN** le module se termine
- **THEN** `pnpm --version` répond une version 11 sous la LTS comme sous la 26, et `openspec --version` répond sous la 26

#### Scenario: Version majeure différente
- **WHEN** pnpm 12 est installé sous la 26
- **THEN** il est remplacé par une version 11

#### Scenario: Projet qui exige une autre version
- **WHEN** l'utilisateur lance pnpm dans un projet dont le champ `packageManager` exige une autre version de pnpm
- **THEN** pnpm exécute la version exigée par le projet

### Requirement: État constaté sans réseau
`module_check` SHALL retourner 0 si et seulement si nvm est présent, la LTS courante connue localement par nvm et une version 26 sont installées, la version par défaut est une 26, pnpm 11 est présent sous chacune des deux versions et `openspec` sous la 26. Ce constat MUST se faire sans accès au réseau ni `sudo`.

#### Scenario: Poste complet
- **WHEN** tout est en place
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: LTS manquante
- **WHEN** seule une version 26 est installée alors que la LTS connue localement est une autre version
- **THEN** `module_check` retourne 1 et le module est proposé
