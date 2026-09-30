## MODIFIED Requirements

### Requirement: Extensions tirées d'une liste versionnée
Le module SHALL installer dans VS Code chaque extension listée dans `config/vscode/extensions.txt` (un identifiant par ligne ; lignes vides et commentaires ignorés) qui n'est pas déjà installée, sans distinction de casse. Une extension installée qui ne figure pas dans la liste MUST être laissée en place. Une installation d'extension qui échoue SHALL être retentée, jusqu'à trois tentatives au total, espacées de quelques secondes ; seul l'échec de la dernière tentative MUST faire échouer le module en nommant l'extension.

#### Scenario: Première installation
- **WHEN** le module s'exécute et qu'aucune extension de la liste n'est installée
- **THEN** toutes les extensions de la liste sont installées

#### Scenario: Extensions partiellement présentes
- **WHEN** une partie des extensions de la liste est déjà installée
- **THEN** seules les manquantes sont installées

#### Scenario: Extension hors liste
- **WHEN** une extension installée à la main n'est pas dans la liste
- **THEN** elle reste installée

#### Scenario: Panne passagère du magasin
- **WHEN** la première tentative d'installation d'une extension échoue (par exemple `Server returned 503`) et qu'une tentative suivante réussit
- **THEN** l'extension est installée et le module ne signale aucun échec

#### Scenario: Extension introuvable
- **WHEN** les trois tentatives d'installation d'une extension de la liste échouent
- **THEN** le module échoue en nommant l'extension
