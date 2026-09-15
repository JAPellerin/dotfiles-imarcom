## Purpose

Point d'entrée interactif de la configuration du poste : découvre les modules, présente un menu à la manière de `create-vite`, exécute les modules choisis dans le bon ordre et rend compte de ce qui reste à faire manuellement.

## ADDED Requirements

### Requirement: Exécution en utilisateur avec élévation unique
Le runner SHALL s'exécuter sous le compte de l'utilisateur (jamais en root) et MUST refuser de démarrer s'il est lancé en root. Il SHALL demander le mot de passe `sudo` une seule fois au démarrage et maintenir l'élévation active pendant toute l'exécution.

#### Scenario: Lancé en root
- **WHEN** `setup.sh` est lancé via `sudo` ou en tant que root
- **THEN** il affiche un message expliquant qu'il faut le lancer en utilisateur et s'arrête avec un code non nul

#### Scenario: Mot de passe demandé une fois
- **WHEN** l'exécution enchaîne plusieurs modules qui utilisent `sudo` pendant plus de quinze minutes
- **THEN** l'utilisateur n'est invité à saisir son mot de passe qu'une seule fois, au démarrage

### Requirement: Menu interactif par défaut
Sans argument, le runner SHALL afficher un menu à sélection multiple listant tous les modules découverts avec leur description et leur état (déjà fait ou non), puis exécuter la sélection. Les modules déjà faits SHALL être présentés mais non présélectionnés.

#### Scenario: Sélection multiple
- **WHEN** l'utilisateur lance `setup.sh` sans argument et coche `base`, `1password`
- **THEN** les deux modules s'exécutent, dans l'ordre de leurs dépendances

#### Scenario: État visible
- **WHEN** le module `base` a déjà été appliqué sur la machine
- **THEN** le menu l'affiche avec un marqueur « déjà fait » et il n'est pas présélectionné

### Requirement: Exécution ciblée par nom
Le runner SHALL accepter un ou plusieurs noms de modules en argument (`setup.sh git node`) et les exécuter sans afficher le menu. Il SHALL aussi accepter `--all` (tous les modules) et `--list` (affiche les modules, leur description et leur état, puis quitte). Un nom inconnu MUST provoquer une erreur listant les noms valides.

#### Scenario: Module par nom
- **WHEN** l'utilisateur lance `setup.sh 1password`
- **THEN** seul le module `1password` (et ses dépendances) s'exécute, sans menu

#### Scenario: Nom inconnu
- **WHEN** l'utilisateur lance `setup.sh navigateurz`
- **THEN** le runner affiche que `navigateurz` n'existe pas, liste les noms valides et sort avec un code non nul

#### Scenario: Liste
- **WHEN** l'utilisateur lance `setup.sh --list`
- **THEN** le runner affiche chaque module avec sa description et son état, sans rien exécuter

### Requirement: Résolution des dépendances
Avant d'exécuter un module, le runner SHALL exécuter ses dépendances (récursivement) qui ne sont pas encore faites, chaque module au plus une fois par exécution. Une dépendance circulaire ou inconnue MUST être détectée avant toute exécution et provoquer une erreur explicite.

#### Scenario: Dépendance non faite
- **WHEN** l'utilisateur lance `setup.sh 1password` et que `base` (dépendance) n'est pas fait
- **THEN** `base` s'exécute avant `1password`

#### Scenario: Dépendance déjà faite
- **WHEN** l'utilisateur lance `setup.sh 1password` et que `base` est déjà fait
- **THEN** `base` est sauté et seul `1password` s'exécute

#### Scenario: Cycle
- **WHEN** deux modules se déclarent mutuellement en dépendance
- **THEN** le runner refuse de démarrer et nomme les modules impliqués

### Requirement: Priorité du module 1password
Lorsque plusieurs modules sont sélectionnés, le runner SHALL exécuter `1password` avant tout autre module qui n'est pas une de ses dépendances, afin que les secrets soient disponibles pour la suite.

#### Scenario: Ordre d'exécution
- **WHEN** l'utilisateur sélectionne `git`, `1password` et `base` dans le menu
- **THEN** l'ordre d'exécution est `base`, `1password`, `git`

### Requirement: Isolation des échecs et résumé final
L'échec d'un module SHALL être consigné sans interrompre les modules suivants qui n'en dépendent pas ; les modules qui en dépendent SHALL être sautés. À la fin, le runner SHALL afficher un résumé par module (fait, déjà fait, sauté, échoué) et la liste consolidée des étapes manuelles restantes déclarées par les modules. Le code de sortie MUST être non nul si au moins un module a échoué.

#### Scenario: Échec isolé
- **WHEN** le module `1password` échoue et que `git` en dépend mais pas `base`
- **THEN** `base` s'exécute quand même, `git` est sauté, le résumé marque `1password` en échec et le code de sortie est non nul

#### Scenario: Étapes manuelles
- **WHEN** un module a déclaré une étape manuelle (ex. « activer l'agent SSH dans 1Password »)
- **THEN** le résumé final la liste sous un titre « Étapes manuelles restantes »

### Requirement: Tolérance à l'absence d'environnement graphique
Le runner SHALL détecter l'absence de session graphique (ex. WSL, serveur) et l'exposer aux modules. Un module marqué comme nécessitant l'environnement graphique SHALL alors être affiché comme « non disponible ici » et sauté, sans faire échouer l'exécution.

#### Scenario: Module graphique en WSL
- **WHEN** `setup.sh` s'exécute dans WSL et qu'un module déclare nécessiter l'environnement graphique
- **THEN** ce module est sauté avec la mention « non disponible ici » et le reste s'exécute normalement

### Requirement: Journalisation
Le runner SHALL écrire un journal complet de l'exécution (sortie des commandes incluse) dans un fichier sous `~/.local/state/dotfiles/`, tout en n'affichant à l'écran que les messages de progression. En cas d'échec, le message d'erreur SHALL indiquer le chemin du journal.

#### Scenario: Diagnostic après échec
- **WHEN** un module échoue
- **THEN** le résumé indique le chemin du journal contenant la sortie complète de la commande fautive
