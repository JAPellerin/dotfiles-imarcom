## Purpose

Amener les fichiers de configuration versionnés dans le dépôt jusqu'à leur place dans `~`, de façon idempotente et réversible, et fournir aux modules le clonage idempotent des dépôts git dont ils dépendent.

## ADDED Requirements

### Requirement: Fichiers de config déployés par liens symboliques
Le socle SHALL fournir un helper qui, pour un fichier `config/<module>/<nom>` du dépôt et une cible dans `~`, crée un lien symbolique absolu de la cible vers le fichier du dépôt. Si la cible est déjà un lien vers ce fichier, le helper SHALL ne rien faire et le signaler. Si la cible est un fichier ou un dossier ordinaire, le helper MUST le sauvegarder (`<cible>.bak`, suffixé de la date si `.bak` existe déjà) avant de créer le lien ; si la cible est un lien vers un autre chemin, il SHALL le remplacer sans sauvegarde. Le helper MUST échouer si le fichier source n'existe pas dans le dépôt. Un second helper SHALL dire si une cible est un lien vers le fichier attendu, sans effet de bord, pour servir de source de vérité à `module_check`.

#### Scenario: Première application
- **WHEN** `~/.zshrc` est un fichier ordinaire et le module `shell` déploie `config/shell/zshrc`
- **THEN** `~/.zshrc.bak` contient l'ancien fichier et `~/.zshrc` est un lien vers `<dépôt>/config/shell/zshrc`

#### Scenario: Réapplication
- **WHEN** `~/.zshrc` est déjà un lien vers `<dépôt>/config/shell/zshrc`
- **THEN** rien n'est modifié, aucune sauvegarde n'est créée et la vérification répond « en place »

#### Scenario: Sauvegarde déjà présente
- **WHEN** `~/.zshrc` est un fichier ordinaire et `~/.zshrc.bak` existe déjà
- **THEN** l'ancien fichier est sauvegardé sous un nom daté et `.bak` n'est pas écrasé

#### Scenario: Source absente
- **WHEN** un module demande le déploiement d'un fichier qui n'existe pas dans le dépôt
- **THEN** le helper échoue avec un message nommant le fichier attendu, sans toucher à la cible

### Requirement: Clonage idempotent de dépôt git
Le socle SHALL fournir un helper qui clone un dépôt git HTTPS dans un dossier donné s'il n'existe pas, et ne fait rien (ou un `git pull --ff-only` si demandé) s'il est déjà cloné depuis la même URL. Si le dossier existe mais n'est pas un clone de cette URL, le helper MUST échouer en nommant le dossier, sans rien écraser. La sortie de git SHALL aller au journal.

#### Scenario: Premier clonage
- **WHEN** `~/.oh-my-zsh` n'existe pas
- **THEN** le dépôt est cloné et le helper réussit

#### Scenario: Déjà cloné
- **WHEN** `~/.oh-my-zsh` est déjà un clone de l'URL demandée
- **THEN** le helper réussit sans recloner

#### Scenario: Dossier étranger
- **WHEN** le dossier existe et n'est pas un clone de l'URL demandée
- **THEN** le helper échoue en nommant le dossier et le laisse intact
