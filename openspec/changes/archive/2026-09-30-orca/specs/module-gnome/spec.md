## MODIFIED Requirements

### Requirement: Dock des applications du script
Les réglages de base SHALL fixer les applications du dock, dans cet ordre : Fichiers, Ghostty, Brave, Firefox, Chrome, 1Password, Orca, VS Code, Claude, Thunderbird, Rocket.Chat, Obsidian, Spotify, l'éditeur de texte de GNOME. Une application absente du poste MUST NOT empêcher l'affichage des autres. Ubuntu écrivant son propre dock dans la base de l'utilisateur dès la première connexion, la valeur par défaut du système ne s'y verrait jamais : tant que le dock en vigueur est exactement celui qu'Ubuntu pose à la première connexion, le module SHALL y écrire le dock du dépôt. De même, quand la liste du dock change dans le dépôt, un dock qui vaut exactement la liste déployée auparavant par le module SHALL être remplacé par la nouvelle. Un dock modifié par l'utilisateur MUST NOT être réécrit.

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

#### Scenario: Orca dans le dock
- **WHEN** Orca est installé
- **THEN** le dock le présente entre 1Password et VS Code
