# module-gnome Specification

## Purpose

Donner au bureau GNOME d'un poste neuf les réglages de base de l'utilisateur (clavier, apparence, dock, confidentialité) et un dock qui présente les applications installées par le script, en valeurs par défaut du système : l'utilisateur garde la main sur tout ce qu'il règle ensuite.

## Requirements

### Requirement: Réglages de base en valeurs par défaut du système
Le module `gnome` (groupe `bureau`, dépend de `base`, nécessite une session graphique) SHALL installer les outils dconf (`dconf-cli`) depuis les dépôts d'Ubuntu s'ils manquent, puis SHALL déployer, par le helper de fichiers système du socle, les réglages de base versionnés dans le dépôt comme valeurs par défaut de la base dconf du système, puis SHALL recompiler cette base. Les réglages de base comprennent : la disposition de clavier canadienne française ; le thème sombre Yaru ; le fond d'écran fourni par Ubuntu, aussi pour l'écran verrouillé ; le dock en bas, avec des icônes de 42 pixels, masqué automatiquement et sans corbeille ; aucune icône du dossier personnel sur le bureau ; aucun rapport d'erreur envoyé ; la localisation désactivée ; la veilleuse sans horaire automatique ; les dossiers affichés en premier dans le sélecteur de fichiers. Le module MUST NOT écrire dans la base dconf de l'utilisateur, hors le dock (exigence « Dock des applications du script »), ni verrouiller un réglage : une valeur que l'utilisateur a réglée garde la priorité, avant comme après le module. Une relance sans changement MUST NOT recompiler la base.

#### Scenario: Poste neuf
- **WHEN** le module s'exécute sur un poste où l'utilisateur n'a rien réglé
- **THEN** à la session suivante, le clavier est en canadien français, le thème est sombre, le dock est en bas et masqué automatiquement, et la localisation est désactivée

#### Scenario: Réglage de l'utilisateur conservé
- **WHEN** l'utilisateur a choisi un autre thème que le thème sombre, avant ou après le module
- **THEN** son choix reste en vigueur, y compris après une relance du module

#### Scenario: Relance sans changement
- **WHEN** les réglages déployés sont identiques à ceux du dépôt
- **THEN** rien n'est réécrit, la base n'est pas recompilée et `sudo` n'est pas appelé

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible (WSL)
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Dock des applications du script
Les réglages de base SHALL fixer les applications du dock, dans cet ordre : Fichiers, Ghostty, Brave, Firefox, Chrome, 1Password, VS Code, Claude, Thunderbird, Rocket.Chat, Obsidian, Spotify, l'éditeur de texte de GNOME. Une application absente du poste MUST NOT empêcher l'affichage des autres. Ubuntu écrivant son propre dock dans la base de l'utilisateur dès la première connexion, la valeur par défaut du système ne s'y verrait jamais : tant que le dock en vigueur est exactement celui qu'Ubuntu pose à la première connexion, le module SHALL y écrire le dock du dépôt. De même, quand la liste du dock change dans le dépôt, un dock qui vaut exactement la liste déployée auparavant par le module SHALL être remplacé par la nouvelle. Un dock modifié par l'utilisateur MUST NOT être réécrit.

#### Scenario: Navigateur choisi
- **WHEN** seul Brave a été installé parmi les trois navigateurs
- **THEN** le dock présente Brave, et ni Firefox ni Chrome

#### Scenario: Dock d'Ubuntu à la première connexion
- **WHEN** le dock de l'utilisateur est encore celui qu'Ubuntu a posé à la première connexion
- **THEN** le module le remplace par le dock du dépôt, sans `sudo`

#### Scenario: Liste du dock mise à jour dans le dépôt
- **WHEN** la liste du dock a changé dans le dépôt et que le dock de l'utilisateur vaut encore la liste déployée auparavant
- **THEN** le module le remplace par la nouvelle liste

#### Scenario: Dock déjà personnalisé
- **WHEN** l'utilisateur a déjà ajouté ou retiré des applications du dock
- **THEN** son dock reste tel qu'il l'a laissé, y compris après une relance du module ou une mise à jour de la liste du dépôt

### Requirement: Profil dconf de l'utilisateur
Pour que la base dconf du système soit lue, le module SHALL créer le profil dconf de l'utilisateur, qui place la base de l'utilisateur avant celle du système, lorsqu'il n'existe pas. Un profil existant identique MUST NOT être réécrit ; un profil existant différent MUST NOT être modifié : le module SHALL alors échouer en le nommant.

#### Scenario: Profil absent
- **WHEN** aucun profil dconf de l'utilisateur n'existe (Ubuntu 26.04)
- **THEN** le module le crée, et la base du système est lue à la session suivante

#### Scenario: Profil différent
- **WHEN** un profil dconf de l'utilisateur existe avec un autre contenu
- **THEN** le module échoue en nommant ce fichier, qui reste intact

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si les outils dconf (`dconf-cli`) sont installés, que le profil dconf et les réglages de base déployés sont identiques à ceux du dépôt, que la base du système a été recompilée après leur dernier déploiement et que le dock en vigueur n'est plus celui d'Ubuntu. Le constat MUST NOT nécessiter `sudo` ni le réseau, et MUST NOT dépendre des valeurs que l'utilisateur a réglées lui-même.

#### Scenario: Tout est en place
- **WHEN** le profil et les réglages sont déployés et la base recompilée
- **THEN** `module_check` retourne 0 et le module est sauté, même si l'utilisateur a changé des réglages depuis

#### Scenario: Réglages du dépôt modifiés
- **WHEN** le fichier des réglages de base a changé dans le dépôt (mise à jour depuis un `dconf dump`)
- **THEN** `module_check` retourne 1 et le module déploie la nouvelle version puis recompile la base
