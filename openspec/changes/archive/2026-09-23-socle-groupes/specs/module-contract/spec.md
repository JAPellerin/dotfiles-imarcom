## ADDED Requirements

### Requirement: Appartenance de l'utilisateur à un groupe
Le socle SHALL fournir des helpers qui : constatent si l'utilisateur courant est membre d'un groupe système **dans la base des groupes du système** (et non dans les groupes de la session courante), par comparaison exacte du nom ; inscrivent l'utilisateur dans un groupe, en créant le groupe s'il n'existe pas, sans réinscrire un membre existant, puis constatent l'inscription ; et déclarent l'étape manuelle de réouverture de session lorsque l'utilisateur est membre dans la base mais que la session courante ne porte pas encore le groupe. Le constat MUST NOT avoir d'effet de bord, pour pouvoir servir de critère à `module_check`. L'étape de réouverture MUST NOT faire échouer le module. Un module MUST NOT inscrire l'utilisateur dans un groupe par ses propres moyens quand ces helpers existent.

#### Scenario: Utilisateur inscrit
- **WHEN** un module demande l'inscription de l'utilisateur dans un groupe dont il n'est pas membre
- **THEN** l'utilisateur apparaît parmi les membres du groupe dans la base des groupes du système

#### Scenario: Déjà membre
- **WHEN** l'utilisateur est déjà membre du groupe dans la base des groupes
- **THEN** rien n'est réécrit et le helper réussit

#### Scenario: Groupe absent
- **WHEN** le groupe n'existe pas encore
- **THEN** il est créé comme groupe système avant l'inscription de l'utilisateur

#### Scenario: Nom proche
- **WHEN** la base des groupes liste un membre dont le nom contient celui de l'utilisateur sans lui être égal
- **THEN** l'utilisateur n'est pas tenu pour membre

#### Scenario: Session à rouvrir
- **WHEN** l'utilisateur est membre dans la base des groupes mais que la session courante ne porte pas le groupe
- **THEN** le helper se termine sans erreur et le résumé final demande de rouvrir la session en nommant le groupe

#### Scenario: Session à jour
- **WHEN** la session courante porte déjà le groupe
- **THEN** aucune étape manuelle n'est déclarée
