## ADDED Requirements

### Requirement: Session 1Password rouverte avant un module qui en dépend
Avant d'installer, puis de nouveau avant de configurer, un module qui dépend, directement ou par ses dépendances, du module `1password`, le runner SHALL constater que la session 1Password est ouverte lorsque le module `1password` a réussi ou était déjà fait dans cette exécution ; si elle est fermée (autorisation expirée), il SHALL la rouvrir par le parcours de connexion du module `1password`, qui peut demander une autorisation dans l'application de bureau ou une connexion en terminal. Si la réouverture échoue ou est refusée, le runner SHALL avertir et MUST NOT empêcher l'exécution du module. Le constat de l'état des modules et l'affichage du menu MUST NOT déclencher de réouverture.

#### Scenario: Session expirée pendant l'exécution
- **WHEN** la session 1Password a expiré entre l'exécution du module `1password` et celle d'un module qui en dépend
- **THEN** le runner rouvre la session avant ce module, qui lit ses secrets sans déclarer d'étape manuelle

#### Scenario: Session expirée pendant l'installation
- **WHEN** la session était ouverte avant l'installation d'un module et a expiré pendant celle-ci
- **THEN** le runner la rouvre avant la configuration de ce module

#### Scenario: Session encore ouverte
- **WHEN** la session est ouverte au moment d'exécuter un module qui dépend de `1password`
- **THEN** aucune réouverture n'est tentée

#### Scenario: Module sans lien avec 1Password
- **WHEN** le module à exécuter ne dépend pas de `1password`
- **THEN** la session n'est ni constatée ni rouverte

#### Scenario: Réouverture refusée
- **WHEN** l'utilisateur refuse l'autorisation demandée
- **THEN** le runner avertit, le module s'exécute quand même et déclare ses étapes manuelles s'il ne peut pas lire ses secrets

#### Scenario: Module déjà fait
- **WHEN** un module qui dépend de `1password` est déjà fait
- **THEN** aucune réouverture n'est tentée pour lui
