## ADDED Requirements

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
