## MODIFIED Requirements

### Requirement: Isolation des échecs et résumé final
L'échec d'un module SHALL être consigné sans interrompre les modules suivants qui n'en dépendent pas ; les modules qui en dépendent SHALL être sautés. À la fin, le runner SHALL afficher un résumé par module (fait, à terminer, déjà fait, sauté, échoué) et la liste consolidée des étapes manuelles restantes déclarées par les modules. Un module dont l'installation et la configuration ont réussi SHALL être marqué « à terminer » (en jaune, avec la mention « étape manuelle ») s'il a déclaré au moins une étape manuelle pendant l'exécution, et « fait » sinon. L'état « à terminer » MUST NOT faire sauter les modules qui en dépendent ni rendre le code de sortie non nul. Un module qui échoue SHALL rester « échoué » même s'il a déclaré une étape manuelle. Le code de sortie MUST être non nul si au moins un module a échoué.

#### Scenario: Échec isolé
- **WHEN** le module `1password` échoue et que `git` en dépend mais pas `base`
- **THEN** `base` s'exécute quand même, `git` est sauté, le résumé marque `1password` en échec et le code de sortie est non nul

#### Scenario: Étapes manuelles
- **WHEN** un module a déclaré une étape manuelle (ex. « activer l'agent SSH dans 1Password »)
- **THEN** le résumé final la liste sous un titre « Étapes manuelles restantes »

#### Scenario: Module réussi avec une étape manuelle
- **WHEN** l'installation et la configuration d'un module réussissent et qu'il a déclaré une étape manuelle (ex. « Passer » au parcours de connexion de `rocketchat`)
- **THEN** le résumé marque ce module « à terminer (étape manuelle) » en jaune, et non « fait », le journal consigne `RESUME rocketchat : a-terminer` et le code de sortie reste nul

#### Scenario: Module réussi sans étape manuelle
- **WHEN** l'installation et la configuration d'un module réussissent sans qu'il déclare d'étape manuelle
- **THEN** le résumé le marque « fait »

#### Scenario: Dépendant d'un module à terminer
- **WHEN** un module est « à terminer » et qu'un module sélectionné en dépend
- **THEN** le module dépendant s'exécute normalement

#### Scenario: Échec après une étape manuelle
- **WHEN** un module déclare une étape manuelle puis échoue
- **THEN** le résumé le marque « échoué », ses dépendants sont sautés et l'étape reste listée sous « Étapes manuelles restantes »
