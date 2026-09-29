## ADDED Requirements

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

## MODIFIED Requirements

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
