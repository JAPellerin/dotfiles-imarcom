## RENAMED Requirements

- FROM: `### Requirement: Installation d'une police depuis une archive`
- TO: `### Requirement: Installation d'une police`

## MODIFIED Requirements

### Requirement: Installation d'une police
Le socle SHALL fournir un helper qui installe une police pour l'utilisateur courant à partir d'une ou plusieurs URL, en indiquant la famille attendue. Chaque URL SHALL être soit une **archive `.zip`**, dont tous les fichiers de police sont extraits, soit un **fichier de police** (`.ttf` ou `.otf`), installé tel quel — le helper distingue les deux par l'extension de l'URL. Le helper SHALL ne rien faire si la famille est déjà connue de `fontconfig`. Sinon il SHALL télécharger les fichiers dans un sous-dossier de `~/.local/share/fonts/`, puis rafraîchir le cache de polices, sans `sudo` (installation utilisateur). Il SHALL installer `fontconfig` s'il manque. Le helper MUST échouer en nommant l'URL fautive si un téléchargement ou une extraction échoue, et MUST NOT laisser de dossier de police incomplet.

#### Scenario: Première installation
- **WHEN** un module demande une police absente du système en désignant une archive
- **THEN** l'archive est téléchargée, les fichiers de police sont extraits sous `~/.local/share/fonts/`, le cache est rafraîchi et la famille est ensuite listée par `fontconfig`

#### Scenario: Première installation depuis des fichiers
- **WHEN** un module demande une police absente du système en désignant plusieurs URL de fichiers `.ttf`
- **THEN** chaque fichier est téléchargé et installé sous `~/.local/share/fonts/`, le cache est rafraîchi et la famille est ensuite listée par `fontconfig`

#### Scenario: Déjà installée
- **WHEN** la famille demandée est déjà connue de `fontconfig`
- **THEN** rien n'est téléchargé et le helper réussit en le signalant

#### Scenario: Archive invalide
- **WHEN** l'archive est injoignable ou illisible
- **THEN** le helper échoue en nommant l'URL et aucun dossier de police partiel ne subsiste

#### Scenario: Un fichier parmi plusieurs est injoignable
- **WHEN** plusieurs URL de fichiers sont données et que l'une d'elles est injoignable
- **THEN** le helper échoue en nommant cette URL et aucun dossier de police partiel ne subsiste
