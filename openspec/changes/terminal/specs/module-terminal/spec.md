## Purpose

Doter le poste d'un émulateur de terminal choisi et configuré : Ghostty depuis les dépôts d'Ubuntu, la police Nerd Font dont Powerlevel10k a besoin pour afficher ses icônes, une configuration versionnée, et Ghostty comme terminal par défaut du bureau.

## ADDED Requirements

### Requirement: Installation de Ghostty depuis les dépôts Ubuntu
Le module `terminal` (groupe `shell`, dépend de `base` et de `shell`, nécessite une session graphique) SHALL installer le paquet `ghostty` depuis les dépôts d'Ubuntu. Aucun dépôt tiers ni paquet téléchargé MUST être utilisé. La dépendance à `shell` est requise parce que la police installée ici n'a d'utilité qu'avec le prompt que `shell` déploie, et que le module doit pouvoir être lancé seul.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine où Ghostty n'est pas installé
- **THEN** `ghostty --version` fonctionne et le lanceur `com.mitchellh.ghostty.desktop` est présent dans le menu des applications

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

#### Scenario: Réexécution
- **WHEN** tout est déjà installé et configuré
- **THEN** `module_check` retourne 0 et le module est sauté

### Requirement: Police MesloLGS NF installée pour l'utilisateur
Le module SHALL installer la famille de police `MesloLGS NF` par le helper de police du socle, à partir des quatre fichiers (normal, gras, italique, gras italique) publiés par le projet Powerlevel10k — ceux que son assistant de configuration installe lui-même. L'installation SHALL être faite pour l'utilisateur courant, sans `sudo`, et SHALL ne rien faire si la famille est déjà connue de `fontconfig`. `module_check` SHALL constater la présence de la famille par le helper de vérification du socle, et non par la présence de fichiers.

#### Scenario: Police absente
- **WHEN** le module s'exécute et que `MesloLGS NF` n'est pas connue de `fontconfig`
- **THEN** les quatre fichiers sont installés sous `~/.local/share/fonts/` et `fc-list : family` liste ensuite exactement `MesloLGS NF`

#### Scenario: Police déjà présente
- **WHEN** `MesloLGS NF` est déjà connue de `fontconfig`
- **THEN** rien n'est téléchargé et le module se termine sans erreur

#### Scenario: Prompt lisible
- **WHEN** l'utilisateur ouvre Ghostty après le module, dans un zsh configuré par le module `shell`
- **THEN** les icônes et les séparateurs de Powerlevel10k s'affichent, sans carré vide ni caractère de remplacement

### Requirement: Configuration de Ghostty versionnée
Le module SHALL déployer `config/terminal/ghostty` vers `~/.config/ghostty/config` par le helper de liens du socle. Ce fichier SHALL fixer la police de Ghostty à la famille installée et sa taille. `module_check` SHALL constater l'état du lien par le helper de vérification.

#### Scenario: Déploiement
- **WHEN** le module se termine
- **THEN** `~/.config/ghostty/config` est un lien vers le fichier du dépôt, et Ghostty ouvert affiche son texte dans `MesloLGS NF`

#### Scenario: Configuration existante
- **WHEN** `~/.config/ghostty/config` est un fichier ordinaire écrit à la main
- **THEN** il est sauvegardé à côté avant que le lien ne soit créé

### Requirement: Ghostty comme terminal par défaut
Le module SHALL faire de Ghostty le terminal par défaut du poste, par deux gestes. Le paquet n'enregistrant pas d'alternative Debian, le module SHALL enregistrer `/usr/bin/ghostty` comme `x-terminal-emulator` puis le sélectionner. Le bureau déléguant le choix du terminal à `xdg-terminal-exec`, le module SHALL en outre placer le fichier de bureau de Ghostty **en tête** de la liste des terminaux de l'utilisateur (`~/.config/xdg-terminals.list`), en conservant derrière les entrées déjà présentes et sans doublon. Le module MUST NOT redéfinir la clé du bureau qui désigne `xdg-terminal-exec` : l'écraser supprimerait cette délégation pour tout le système. Le module SHALL vérifier le résultat après application ; s'il ne peut pas l'établir, il SHALL le déclarer comme étape manuelle plutôt que de se déclarer fait.

#### Scenario: Terminal par défaut appliqué
- **WHEN** le module se termine sur un poste GNOME
- **THEN** l'alternative `x-terminal-emulator` désigne `/usr/bin/ghostty`, le fichier de bureau de Ghostty est en tête de `~/.config/xdg-terminals.list`, et le raccourci du bureau qui ouvre un terminal ouvre Ghostty

#### Scenario: Réexécution
- **WHEN** le module est réexécuté alors que Ghostty est déjà le terminal par défaut
- **THEN** rien n'est réécrit et le module se termine sans erreur

#### Scenario: Liste de terminaux existante
- **WHEN** `~/.config/xdg-terminals.list` contient déjà d'autres terminaux
- **THEN** Ghostty passe en tête et les autres entrées sont conservées derrière lui, sans doublon

#### Scenario: Réglage impossible à constater
- **WHEN** le module ne parvient pas à vérifier que Ghostty est bien le terminal par défaut
- **THEN** il le signale, déclare l'étape manuelle correspondante et se termine sans erreur
