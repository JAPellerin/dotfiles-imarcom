## Purpose

Définir la forme obligatoire d'un module pour que le runner puisse le découvrir, afficher son état, résoudre ses dépendances et l'exécuter de façon idempotente ; tout module présent ou futur MUST s'y conformer.

## ADDED Requirements

### Requirement: Un fichier par module, découvert automatiquement
Chaque module SHALL être un fichier `modules/NN-<nom>.sh` où `NN` est un préfixe numérique à deux chiffres servant d'ordre d'affichage par défaut et `<nom>` l'identifiant du module (kebab-case). Le runner SHALL découvrir les modules en listant ce dossier, sans registre à maintenir à la main.

#### Scenario: Ajout d'un module
- **WHEN** un nouveau fichier `modules/40-node.sh` conforme est ajouté
- **THEN** il apparaît dans `setup.sh --list` et dans le menu sans autre modification

### Requirement: Métadonnées obligatoires
Chaque module SHALL déclarer `MODULE_NAME` (identique au `<nom>` du fichier), `MODULE_DESC` (une ligne, en français) et `MODULE_DEPS` (liste de noms de modules, possiblement vide). Il MAY déclarer `MODULE_NEEDS_GUI=1` s'il nécessite une session graphique. Un module dont les métadonnées obligatoires manquent ou dont `MODULE_NAME` diffère du nom de fichier MUST être rejeté par le runner avec un message nommant le fichier.

#### Scenario: Module invalide
- **WHEN** `modules/50-browsers.sh` ne déclare pas `MODULE_DESC`
- **THEN** `setup.sh` signale le fichier et le champ manquant, et refuse de démarrer

### Requirement: Fonctions du cycle de vie
Chaque module SHALL définir trois fonctions : `module_check` (retourne 0 si le module est déjà appliqué, 1 sinon, sans rien modifier), `module_install` (installe les logiciels) et `module_configure` (applique la configuration, y compris les secrets). Le runner SHALL appeler `module_check` avant l'exécution et sauter le module s'il retourne 0, puis `module_install` et `module_configure` dans cet ordre.

#### Scenario: Module déjà appliqué
- **WHEN** `module_check` retourne 0
- **THEN** `module_install` et `module_configure` ne sont pas appelées et le module est marqué « déjà fait »

#### Scenario: Application complète
- **WHEN** `module_check` retourne 1
- **THEN** `module_install` puis `module_configure` sont appelées ; si l'une échoue, le module est marqué « échoué »

### Requirement: Idempotence
`module_install` et `module_configure` MUST pouvoir être réexécutées sur une machine où le module est partiellement ou totalement appliqué sans erreur ni duplication (dépôt apt ajouté deux fois, ligne dupliquée dans un fichier de config, etc.).

#### Scenario: Réexécution forcée
- **WHEN** un module déjà appliqué est réexécuté (ex. après un échec partiel corrigé à la main)
- **THEN** il se termine sans erreur et l'état final est identique à une première application

### Requirement: Interactivité et choix
Un module MAY poser des questions à l'utilisateur (choix d'options, confirmation) via les helpers d'interface fournis par le socle. Ces questions SHALL être posées au début de `module_install`, avant toute action longue, pour que l'utilisateur ne soit pas sollicité au milieu d'une installation.

#### Scenario: Module avec options
- **WHEN** le module `browsers` propose Brave, Chrome et Firefox
- **THEN** la sélection est demandée avant le premier `apt install`, puis les installations s'enchaînent sans nouvelle question

### Requirement: Déclaration des étapes manuelles
Un module SHALL pouvoir déclarer, via un helper du socle, une ou plusieurs étapes manuelles que le script ne peut pas automatiser ; le runner les reprend dans le résumé final.

#### Scenario: Étape manuelle déclarée
- **WHEN** le module `1password` déclare « Activer l'agent SSH : Settings > Developer »
- **THEN** cette ligne figure dans la section « Étapes manuelles restantes » du résumé final

### Requirement: Accès aux helpers du socle
Un module SHALL pouvoir utiliser les helpers du socle pour : journaliser, exécuter une commande avec `sudo`, ajouter un dépôt apt avec sa clé GPG (fichier `.sources` deb822, clé dans `/etc/apt/keyrings/`), installer des paquets apt, lire un secret 1Password, poser une question ou un choix à l'utilisateur, et savoir si une session graphique est disponible. Un module MUST NOT appeler `gum` ni `apt` directement quand un helper existe pour l'opération.

#### Scenario: Ajout de dépôt apt
- **WHEN** un module ajoute le dépôt Docker via le helper avec l'URL de la clé et l'URL du dépôt
- **THEN** la clé est écrite dans `/etc/apt/keyrings/`, le fichier `.sources` est créé une seule fois et `apt update` est exécuté
