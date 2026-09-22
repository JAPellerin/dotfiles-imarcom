## MODIFIED Requirements

### Requirement: Accès aux helpers du socle
Un module SHALL pouvoir utiliser les helpers du socle pour : journaliser, exécuter une commande avec `sudo`, ajouter un dépôt apt avec sa clé GPG (fichier `.sources` deb822, clé dans `/etc/apt/keyrings/`), installer des paquets apt, installer un paquet `.deb` téléchargé depuis une URL, installer une police depuis une archive, lire un secret 1Password, poser une question ou un choix à l'utilisateur, et savoir si une session graphique est disponible. Un module MUST NOT appeler `gum` ni `apt` directement quand un helper existe pour l'opération, ni télécharger et installer un `.deb` ou une police par ses propres moyens.

#### Scenario: Ajout de dépôt apt
- **WHEN** un module ajoute le dépôt Docker via le helper avec l'URL de la clé et l'URL du dépôt
- **THEN** la clé est écrite dans `/etc/apt/keyrings/`, le fichier `.sources` est créé une seule fois et `apt update` est exécuté

## ADDED Requirements

### Requirement: Installation d'un paquet .deb depuis une URL
Le socle SHALL fournir un helper qui installe un paquet `.deb` désigné par une URL et un nom de paquet, pour les logiciels distribués hors dépôt apt (`.deb` publié sur le site de l'éditeur ou en *release* GitHub). Le helper SHALL ne rien faire et le signaler si le paquet est déjà installé. Sinon il SHALL télécharger le fichier dans un emplacement temporaire nettoyé en fin d'exécution, refuser un fichier qui n'est pas un paquet Debian valide, puis l'installer **en laissant apt résoudre les dépendances** (et non par `dpkg -i` seul), sans question interactive. Le helper MUST échouer en nommant l'URL si le téléchargement échoue, sans rien installer.

#### Scenario: Première installation
- **WHEN** un module demande l'installation d'un `.deb` par son URL et que le paquet est absent
- **THEN** le fichier est téléchargé, installé avec ses dépendances, et le fichier temporaire n'existe plus en fin d'exécution

#### Scenario: Déjà installé
- **WHEN** le paquet est déjà installé
- **THEN** rien n'est téléchargé ni installé, et le helper réussit en le signalant

#### Scenario: Téléchargement impossible
- **WHEN** l'URL est injoignable ou renvoie une erreur
- **THEN** le helper échoue en nommant l'URL et aucun paquet n'est installé

#### Scenario: Fichier invalide
- **WHEN** l'URL renvoie un fichier qui n'est pas un paquet Debian
- **THEN** le helper échoue sans appeler apt

### Requirement: Installation d'une police depuis une archive
Le socle SHALL fournir un helper qui installe une police pour l'utilisateur courant à partir d'une archive `.zip` désignée par une URL, en indiquant la famille attendue. Le helper SHALL ne rien faire si la famille est déjà connue de `fontconfig`. Sinon il SHALL télécharger et extraire les fichiers de police dans un sous-dossier de `~/.local/share/fonts/`, puis rafraîchir le cache de polices, sans `sudo` (installation utilisateur). Il SHALL installer `fontconfig` s'il manque. Le helper MUST échouer en nommant l'URL si le téléchargement ou l'extraction échoue, et MUST NOT laisser de dossier de police incomplet.

#### Scenario: Première installation
- **WHEN** un module demande une police absente du système
- **THEN** l'archive est téléchargée, les fichiers de police sont extraits sous `~/.local/share/fonts/`, le cache est rafraîchi et la famille est ensuite listée par `fontconfig`

#### Scenario: Déjà installée
- **WHEN** la famille demandée est déjà connue de `fontconfig`
- **THEN** rien n'est téléchargé et le helper réussit en le signalant

#### Scenario: Archive invalide
- **WHEN** l'archive est injoignable ou illisible
- **THEN** le helper échoue en nommant l'URL et aucun dossier de police partiel ne subsiste
