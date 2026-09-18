# bootstrap Specification

## Purpose

Permettre de lancer la configuration complète d'une machine Ubuntu vierge avec une seule commande `curl | bash`, sans aucun prérequis autre qu'un accès réseau et `sudo`.

## Requirements

### Requirement: Lancement en une seule commande
Le bootstrap SHALL être un script Bash autonome, hébergé à une URL publique, exécutable par `curl -fsSL <url> | bash` sur une installation fraîche d'Ubuntu 26.04, sans dépendre d'aucun fichier du dépôt.

#### Scenario: Machine vierge
- **WHEN** l'utilisateur exécute `curl -fsSL <url-raw>/bootstrap.sh | bash` sur une Ubuntu 26.04 fraîche
- **THEN** le bootstrap se termine en lançant `setup.sh` depuis le dépôt cloné, sans autre action de l'utilisateur que la saisie de son mot de passe `sudo`

### Requirement: Installation des prérequis
Le bootstrap SHALL installer `git` et `gum` depuis les dépôts apt d'Ubuntu s'ils sont absents, et SHALL ne rien réinstaller s'ils sont déjà présents.

#### Scenario: Prérequis absents
- **WHEN** `git` ou `gum` n'est pas installé
- **THEN** le bootstrap l'installe via `apt` après un `apt update`

#### Scenario: Prérequis déjà présents
- **WHEN** `git` et `gum` sont déjà installés
- **THEN** le bootstrap passe à l'étape suivante sans appeler `apt install`

### Requirement: Clonage du dépôt
Le bootstrap SHALL cloner le dépôt public en HTTPS dans `~/dotfiles` s'il n'existe pas. Si `~/dotfiles` est déjà un clone du dépôt, le bootstrap SHALL le mettre à jour (`git pull`) plutôt que de le recloner. Si `~/dotfiles` existe mais n'est pas un dépôt git, le bootstrap MUST s'arrêter avec un message explicite sans rien écraser.

#### Scenario: Premier lancement
- **WHEN** `~/dotfiles` n'existe pas
- **THEN** le dépôt est cloné en HTTPS dans `~/dotfiles`

#### Scenario: Relance
- **WHEN** `~/dotfiles` est déjà un clone du dépôt
- **THEN** le bootstrap exécute `git pull` et continue

#### Scenario: Dossier étranger
- **WHEN** `~/dotfiles` existe et n'est pas un dépôt git
- **THEN** le bootstrap affiche une erreur nommant le dossier et s'arrête avec un code de sortie non nul

### Requirement: Passage de relais à setup.sh
Le bootstrap SHALL exécuter `~/dotfiles/setup.sh` en remplaçant son propre processus (`exec`), avec l'entrée standard rattachée au terminal pour que les prompts interactifs fonctionnent malgré le lancement par `curl | bash`.

#### Scenario: Interactivité conservée
- **WHEN** le bootstrap a été lancé par `curl | bash` et passe la main à `setup.sh`
- **THEN** les menus `gum` de `setup.sh` reçoivent les frappes clavier de l'utilisateur

### Requirement: Arrêt sur erreur
Le bootstrap MUST s'arrêter à la première commande en échec, afficher l'étape qui a échoué et retourner un code de sortie non nul.

#### Scenario: Échec réseau
- **WHEN** `apt update` ou `git clone` échoue
- **THEN** le bootstrap affiche l'étape en échec et s'arrête sans lancer `setup.sh`
