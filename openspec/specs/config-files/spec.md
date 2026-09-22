# config-files Specification

## Purpose

Amener les fichiers de configuration versionnés dans le dépôt jusqu'à leur place dans `~`, de façon idempotente et réversible, et fournir aux modules le clonage idempotent des dépôts git dont ils dépendent.

## Requirements

### Requirement: Fichiers de config déployés par liens symboliques
Le socle SHALL fournir un helper qui, pour un fichier `config/<module>/<nom>` du dépôt et une cible dans `~`, crée un lien symbolique absolu de la cible vers le fichier du dépôt. Si la cible est déjà un lien vers ce fichier, le helper SHALL ne rien faire et le signaler. Si la cible est un fichier ou un dossier ordinaire, le helper MUST le sauvegarder (`<cible>.bak`, suffixé de la date si `.bak` existe déjà) avant de créer le lien ; si la cible est un lien vers un autre chemin, il SHALL le remplacer sans sauvegarde. Le helper MUST échouer si le fichier source n'existe pas dans le dépôt. Un second helper SHALL dire si une cible est un lien vers le fichier attendu, sans effet de bord, pour servir de source de vérité à `module_check`.

#### Scenario: Première application
- **WHEN** `~/.zshrc` est un fichier ordinaire et le module `shell` déploie `config/shell/zshrc`
- **THEN** `~/.zshrc.bak` contient l'ancien fichier et `~/.zshrc` est un lien vers `<dépôt>/config/shell/zshrc`

#### Scenario: Réapplication
- **WHEN** `~/.zshrc` est déjà un lien vers `<dépôt>/config/shell/zshrc`
- **THEN** rien n'est modifié, aucune sauvegarde n'est créée et la vérification répond « en place »

#### Scenario: Sauvegarde déjà présente
- **WHEN** `~/.zshrc` est un fichier ordinaire et `~/.zshrc.bak` existe déjà
- **THEN** l'ancien fichier est sauvegardé sous un nom daté et `.bak` n'est pas écrasé

#### Scenario: Source absente
- **WHEN** un module demande le déploiement d'un fichier qui n'existe pas dans le dépôt
- **THEN** le helper échoue avec un message nommant le fichier attendu, sans toucher à la cible

### Requirement: Clonage idempotent de dépôt git
Le socle SHALL fournir un helper qui clone un dépôt git HTTPS dans un dossier donné s'il n'existe pas, et ne fait rien s'il est déjà cloné depuis la même URL (pas de mise à jour automatique : elle reste une décision explicite du module). Si le dossier existe mais n'est pas un clone de cette URL, le helper MUST échouer en nommant le dossier, sans rien écraser. La sortie de git SHALL aller au journal.

#### Scenario: Premier clonage
- **WHEN** `~/.oh-my-zsh` n'existe pas
- **THEN** le dépôt est cloné et le helper réussit

#### Scenario: Déjà cloné
- **WHEN** `~/.oh-my-zsh` est déjà un clone de l'URL demandée
- **THEN** le helper réussit sans recloner

#### Scenario: Dossier étranger
- **WHEN** le dossier existe et n'est pas un clone de l'URL demandée
- **THEN** le helper échoue en nommant le dossier et le laisse intact

### Requirement: Fragments de configuration shell déposés par les modules
Un module qui a besoin d'ajouter des variables d'environnement ou des alias communs à bash et zsh SHALL versionner un fragment `config/<module>/commonrc.sh` et le déployer, par le helper de liens du socle, vers `<dossier des fragments>/<module>.sh` — où le dossier des fragments est `~/.commonrc.d` (surchargeable pour les tests). Un lien SHALL être créé par fragment, de sorte que le helper de vérification des liens serve de source de vérité à `module_check` et qu'un fragment ne soit présent que si son module est installé. Le fragment MUST être en syntaxe POSIX. Un module MUST NOT éditer `config/shell/commonrc` : ce fichier n'accueille que ce qui est commun à tous les postes, indépendamment des modules installés.

#### Scenario: Dépôt d'un fragment
- **WHEN** un module déploie son fragment `config/<module>/commonrc.sh`
- **THEN** `~/.commonrc.d/<module>.sh` est un lien vers le fichier du dépôt, et le helper de vérification répond « en place »

#### Scenario: Module non installé
- **WHEN** un module versionne un fragment mais n'a pas été exécuté
- **THEN** aucun lien ne porte son nom dans `~/.commonrc.d` et son fragment n'est pas chargé par les shells

#### Scenario: Réexécution
- **WHEN** un module déjà appliqué redéploie son fragment
- **THEN** le lien existant est reconnu, rien n'est réécrit et aucune sauvegarde n'est créée
