# setup-runner Specification

## Purpose

Point d'entrée interactif de la configuration du poste : découvre les modules, présente un menu à la manière de `create-vite`, exécute les modules choisis dans le bon ordre et rend compte de ce qui reste à faire manuellement.

## Requirements

### Requirement: Exécution en utilisateur avec élévation unique
Le runner SHALL s'exécuter sous le compte de l'utilisateur (jamais en root) et MUST refuser de démarrer s'il est lancé en root. Pour exécuter des modules, il SHALL demander le mot de passe `sudo` une seule fois au démarrage et maintenir l'élévation active pendant toute l'exécution. Les commandes des projets (`--snapshot-projets`, `--pull-projets`) MUST NOT le demander au démarrage : elles SHALL le demander seulement au moment où elles doivent écrire un fichier système.

#### Scenario: Lancé en root
- **WHEN** `setup.sh` est lancé via `sudo` ou en tant que root
- **THEN** il affiche un message expliquant qu'il faut le lancer en utilisateur et s'arrête avec un code non nul

#### Scenario: Mot de passe demandé une fois
- **WHEN** l'exécution enchaîne plusieurs modules qui utilisent `sudo` pendant plus de quinze minutes
- **THEN** l'utilisateur n'est invité à saisir son mot de passe qu'une seule fois, au démarrage

#### Scenario: Commande des projets sans écriture système
- **WHEN** l'utilisateur lance `setup.sh --snapshot-projets`, ou `setup.sh --pull-projets` alors que tous les domaines locaux sont déjà dans `/etc/hosts`
- **THEN** aucun mot de passe `sudo` n'est demandé

### Requirement: Menu interactif par défaut
Sans argument, le runner SHALL afficher un menu à sélection multiple listant tous les modules découverts, chacun sous la forme `[groupe] nom — description — état`, puis exécuter la sélection. Les modules pas encore faits SHALL être présélectionnés ; les modules déjà faits SHALL être présentés mais non présélectionnés. Ainsi, valider le menu sans rien changer installe tout ce qui manque. Le menu SHALL annoncer, dans son en-tête, les gestes pour cocher ou décocher un module, pour tout cocher ou tout décocher d'un coup, et pour lancer la sélection.

#### Scenario: Machine vierge
- **WHEN** l'utilisateur lance `setup.sh` sur une machine où aucun module n'est fait et valide le menu sans rien changer
- **THEN** tous les modules disponibles dans cet environnement s'exécutent, dans l'ordre de leurs dépendances

#### Scenario: Sélection ajustée
- **WHEN** l'utilisateur lance `setup.sh` sans argument, décoche tout sauf `base` et `1password`
- **THEN** seuls ces deux modules s'exécutent, dans l'ordre de leurs dépendances

#### Scenario: État visible
- **WHEN** le module `base` a déjà été appliqué sur la machine
- **THEN** le menu l'affiche sous `[systeme] base` avec un marqueur « déjà fait » et il n'est pas présélectionné

#### Scenario: Tout décocher
- **WHEN** l'utilisateur ouvre le menu et suit l'en-tête pour tout décocher, puis coche un seul module
- **THEN** seul ce module (et ses dépendances) s'exécute

### Requirement: Exécution ciblée par nom
Le runner SHALL accepter un ou plusieurs noms de modules en argument (`setup.sh git node`) et les exécuter sans afficher le menu. Il SHALL aussi accepter `--all` (tous les modules) et `--list` (affiche les modules avec leur groupe, leur description et leur état, puis quitte). Un nom inconnu MUST provoquer une erreur listant les noms valides.

#### Scenario: Module par nom
- **WHEN** l'utilisateur lance `setup.sh 1password`
- **THEN** seul le module `1password` (et ses dépendances) s'exécute, sans menu

#### Scenario: Nom inconnu
- **WHEN** l'utilisateur lance `setup.sh navigateurz`
- **THEN** le runner affiche que `navigateurz` n'existe pas, liste les noms valides et sort avec un code non nul

#### Scenario: Liste
- **WHEN** l'utilisateur lance `setup.sh --list`
- **THEN** le runner affiche chaque module avec son groupe, sa description et son état, sans rien exécuter

### Requirement: Commandes des projets
Le runner SHALL accepter `--snapshot-projets` (relever les dépôts du poste dans 1Password) et `--pull-projets` (mettre à jour les projets du poste d'après 1Password), exécutées par le module `projets` sans passer par le menu ni par les états des modules, et SHALL les présenter dans son aide. Ces commandes MUST NOT être lancées en root. Elles demandent une session 1Password : si le module `1password` n'est pas « déjà fait », le runner SHALL l'exécuter d'abord, dans le même processus (la session ouverte sans l'application ne vit que dans ce processus), et SHALL s'arrêter avec un code non nul, sans lancer la commande, si ce module échoue — une installation de `1password` qui demanderait `sudo` fait échouer ce module en invitant à lancer `setup.sh 1password`. Sans module `projets`, ces options MUST provoquer une erreur qui le nomme.

#### Scenario: Relevé
- **WHEN** l'utilisateur lance `setup.sh --snapshot-projets` avec une session 1Password
- **THEN** l'arbre des projets est écrit dans 1Password, sans menu ni résumé des modules, et sans demande de mot de passe `sudo`

#### Scenario: Session 1Password à ouvrir
- **WHEN** l'utilisateur lance `setup.sh --pull-projets` sans session 1Password
- **THEN** le module `1password` s'exécute d'abord et ouvre la session, puis la mise à jour des projets s'exécute

#### Scenario: 1Password en échec
- **WHEN** le module `1password` échoue avant une commande des projets
- **THEN** la commande n'est pas lancée et le runner sort avec un code non nul

#### Scenario: Aide
- **WHEN** l'utilisateur lance `setup.sh --help`
- **THEN** l'aide présente `--snapshot-projets` et `--pull-projets` avec `--list` et `--all`

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

### Requirement: Session 1Password rouverte avant un module qui en dépend
Avant d'installer, puis de nouveau avant de configurer, un module qui dépend, directement ou par ses dépendances, du module `1password`, le runner SHALL constater que la session 1Password est ouverte lorsque le module `1password` a réussi ou était déjà fait dans cette exécution ; si elle est fermée (autorisation expirée), il SHALL la rouvrir par le parcours de connexion du module `1password`, qui peut demander une autorisation dans l'application de bureau ou une connexion en terminal. Si la réouverture échoue ou est refusée, le runner SHALL avertir et MUST NOT empêcher l'exécution du module. Le constat de l'état des modules et l'affichage du menu MUST NOT déclencher de réouverture.

#### Scenario: Session expirée pendant l'exécution
- **WHEN** la session 1Password a expiré entre l'exécution du module `1password` et celle d'un module qui en dépend
- **THEN** le runner rouvre la session avant ce module, qui lit ses secrets sans déclarer d'étape manuelle

#### Scenario: Session expirée pendant l'installation
- **WHEN** la session était ouverte avant l'installation d'un module et a expiré pendant celle-ci
- **THEN** le runner la rouvre avant la configuration de ce module

#### Scenario: Session encore ouverte
- **WHEN** la session est ouverte au moment d'exécuter un module qui dépend de `1password`
- **THEN** aucune réouverture n'est tentée

#### Scenario: Module sans lien avec 1Password
- **WHEN** le module à exécuter ne dépend pas de `1password`
- **THEN** la session n'est ni constatée ni rouverte

#### Scenario: Réouverture refusée
- **WHEN** l'utilisateur refuse l'autorisation demandée
- **THEN** le runner avertit, le module s'exécute quand même et déclare ses étapes manuelles s'il ne peut pas lire ses secrets

#### Scenario: Module déjà fait
- **WHEN** un module qui dépend de `1password` est déjà fait
- **THEN** aucune réouverture n'est tentée pour lui

### Requirement: Isolation des échecs et résumé final
L'échec d'un module SHALL être consigné sans interrompre les modules suivants qui n'en dépendent pas ; les modules qui en dépendent SHALL être sautés. À la fin, le runner SHALL afficher un résumé par module (fait, à terminer, déjà fait, sauté, échoué, non disponible ici) et la liste consolidée des étapes manuelles restantes déclarées par les modules. Un module dont l'installation et la configuration ont réussi SHALL être marqué « à terminer » (en jaune, avec la mention « étape manuelle ») s'il a déclaré au moins une étape manuelle pendant l'exécution, et « fait » sinon. L'état « à terminer » MUST NOT faire sauter les modules qui en dépendent ni rendre le code de sortie non nul. Un module qui échoue SHALL rester « échoué » même s'il a déclaré une étape manuelle. Le code de sortie MUST être non nul si au moins un module a échoué.

#### Scenario: Échec isolé
- **WHEN** le module `1password` échoue et que `git` en dépend mais pas `base`
- **THEN** `base` s'exécute quand même, `git` est sauté, le résumé marque `1password` en échec et le code de sortie est non nul

#### Scenario: Étapes manuelles
- **WHEN** un module a déclaré une étape manuelle (ex. « activer l'agent SSH dans 1Password »)
- **THEN** le résumé final la liste sous un titre « Étapes manuelles restantes »

#### Scenario: Module réussi avec une étape manuelle
- **WHEN** l'installation et la configuration d'un module réussissent et qu'il a déclaré une étape manuelle (ex. « Passer » au parcours de connexion de `rocketchat`)
- **THEN** le résumé marque ce module « à terminer (étape manuelle) » en jaune, et non « fait », le journal consigne `RESUME rocketchat : a-terminer` et le code de sortie reste nul

#### Scenario: Module réussi sans étape manuelle
- **WHEN** l'installation et la configuration d'un module réussissent sans qu'il déclare d'étape manuelle
- **THEN** le résumé le marque « fait »

#### Scenario: Dépendant d'un module à terminer
- **WHEN** un module est « à terminer » et qu'un module sélectionné en dépend
- **THEN** le module dépendant s'exécute normalement

#### Scenario: Échec après une étape manuelle
- **WHEN** un module déclare une étape manuelle puis échoue
- **THEN** le résumé le marque « échoué », ses dépendants sont sautés et l'étape reste listée sous « Étapes manuelles restantes »

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
