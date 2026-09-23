## ADDED Requirements

### Requirement: URL d'un fichier publié dans les releases GitHub
Le socle SHALL fournir un helper qui, pour un dépôt GitHub et un motif de nom de fichier, renvoie l'URL de téléchargement du fichier correspondant dans **la plus récente des releases publiées qui en contient un**. Les brouillons et les préversions MUST être écartés. Une release récente qui ne contient aucun fichier correspondant MUST être sautée au profit de la précédente. Si aucune release ne contient un tel fichier, ou si l'API de GitHub ne répond pas, le helper MUST échouer en nommant le dépôt et le motif, sans rien imprimer sur sa sortie standard.

#### Scenario: Dernière release complète
- **WHEN** la release la plus récente contient un fichier correspondant au motif
- **THEN** le helper imprime l'URL de ce fichier

#### Scenario: Dernière release sans le fichier
- **WHEN** la release la plus récente ne contient pas de fichier correspondant, mais la précédente oui
- **THEN** le helper imprime l'URL du fichier de la release précédente

#### Scenario: Préversion plus récente
- **WHEN** une préversion plus récente contient un fichier correspondant
- **THEN** elle est ignorée et l'URL vient de la dernière release publiée

#### Scenario: Aucun fichier correspondant
- **WHEN** aucune release ne contient de fichier correspondant au motif
- **THEN** le helper échoue en nommant le dépôt et le motif, et n'imprime rien sur sa sortie standard

#### Scenario: API injoignable
- **WHEN** l'API de GitHub ne répond pas ou renvoie une erreur
- **THEN** le helper échoue en nommant le dépôt
