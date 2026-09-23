## Purpose

Installer les outils en ligne de commande du travail quotidien — Claude Code et la CLI Atlassian Teamwork Graph — par les installateurs officiels de leurs éditeurs, pour l'utilisateur courant, sans que ces installateurs modifient les fichiers du shell versionnés dans le dépôt.

## ADDED Requirements

### Requirement: Claude Code par son installateur natif
Le module `dev-tools` (groupe `dev`, dépend de `base` et de `shell`, sans session graphique requise) SHALL installer Claude Code pour l'utilisateur courant par l'installateur natif que recommande sa documentation, sans `sudo`, si la commande `claude` n'est pas déjà installée dans `~/.local/bin`. Une installation existante MUST NOT être réinstallée ni mise à jour par le module.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Claude Code
- **THEN** `~/.local/bin/claude --version` répond une version de Claude Code

#### Scenario: Déjà installé
- **WHEN** `~/.local/bin/claude` existe et répond
- **THEN** l'installateur n'est pas lancé

### Requirement: twg par l'installateur d'Atlassian, sans connexion
Le module SHALL installer la CLI `twg` pour l'utilisateur courant par l'installateur public d'Atlassian, sans `sudo`, sans lancer la connexion et sans ajouter de skills aux agents, si `twg` n'est pas déjà installé dans `~/.local/bin`. L'installation MUST NOT attendre de réponse de l'utilisateur : l'acceptation des conditions d'utilisation d'Atlassian est donnée par le module, à la demande de l'utilisateur. Une installation existante MUST NOT être réinstallée par le module.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans `twg`
- **THEN** `~/.local/bin/twg --help` répond, aucune fenêtre de connexion n'a été ouverte et aucune question n'a été posée

#### Scenario: Déjà installé
- **WHEN** `~/.local/bin/twg` existe
- **THEN** l'installateur n'est pas lancé

### Requirement: Fichiers du shell préservés
Les installateurs SHALL être lancés dans un environnement où `~/.local/bin` figure déjà dans le `PATH`. Le module MUST NOT laisser un installateur ajouter une ligne à un fichier de configuration du shell (`~/.zshrc`, `~/.bashrc`, `~/.bash_profile`, `~/.profile`) : `~/.local/bin` est déjà dans le `PATH` par la configuration commune du module `shell`.

#### Scenario: Installation sur un poste où ~/.local/bin n'est pas dans le PATH du runner
- **WHEN** le module installe les deux outils alors que le `PATH` du runner ne contient pas `~/.local/bin`
- **THEN** aucun fichier de configuration du shell n'est modifié, et le dépôt de dotfiles ne présente aucune modification

### Requirement: Connexions déclarées comme étapes manuelles
Le module SHALL déclarer une étape manuelle pour chaque outil installé dont la connexion n'est pas constatée sur disque : `twg login` pour twg, et le premier lancement de `claude` pour Claude Code. Ces étapes MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Poste neuf
- **WHEN** le module se termine sur un poste où aucun des deux outils n'est connecté
- **THEN** le résumé final demande de lancer `twg login` et de se connecter à Claude Code

#### Scenario: Connexions déjà faites
- **WHEN** les deux outils sont déjà connectés
- **THEN** aucune étape manuelle n'est déclarée à ce titre

### Requirement: État constaté localement
`module_check` SHALL retourner 0 si et seulement si `~/.local/bin/claude` et `~/.local/bin/twg` existent et sont exécutables. Ce constat MUST se faire sans accès au réseau ni `sudo`.

#### Scenario: Outils présents
- **WHEN** les deux commandes sont installées
- **THEN** `module_check` retourne 0, que les connexions soient faites ou non

#### Scenario: Un outil manquant
- **WHEN** `twg` est absent
- **THEN** `module_check` retourne 1
