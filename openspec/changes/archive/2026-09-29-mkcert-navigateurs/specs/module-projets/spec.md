## MODIFIED Requirements

### Requirement: Autorité de certification locale
Le module SHALL installer `mkcert` et `libnss3-tools` depuis les dépôts d'Ubuntu et SHALL installer l'autorité de certification locale de `mkcert` dans le magasin du système, pour que les certificats de développement des projets soient reconnus. Le module SHALL aussi rendre l'autorité reconnue des navigateurs : il SHALL créer la base de certificats partagée de Chromium, Brave et Chrome dans le dossier personnel lorsqu'elle n'existe pas, et SHALL ajouter l'autorité à chaque base de certificats de navigateur présente (base partagée, profils Firefox), sans modifier leurs autres certificats. Une autorité déjà installée MUST NOT être recréée ni ajoutée deux fois à une même base.

#### Scenario: Premier passage
- **WHEN** le module s'exécute sur un poste sans `mkcert`
- **THEN** `mkcert` est installé, son autorité existe et figure dans le magasin de certificats du système

#### Scenario: Réexécution
- **WHEN** l'autorité existe déjà
- **THEN** elle est conservée telle quelle

#### Scenario: Navigateurs sans base au premier passage
- **WHEN** le module s'exécute alors qu'aucun navigateur n'a encore créé de base de certificats
- **THEN** la base partagée de Chromium est créée et contient l'autorité, et une page servie par un certificat de `mkcert` s'ouvre sans avertissement dans Brave

#### Scenario: Profil Firefox créé après le module
- **WHEN** Firefox est lancé pour la première fois après le passage du module
- **THEN** `module_check` retourne 1, et le passage suivant ajoute l'autorité à son profil sans toucher aux autres bases

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si au moins un dépôt git existe sous `~/projets`, que `bitbucket.org` est un hôte connu, que `mkcert` et `libnss3-tools` sont installés, que l'autorité de `mkcert` est présente dans le magasin du système, que la base de certificats partagée de Chromium existe et que chaque base de certificats de navigateur présente contient l'autorité, et que l'accès SSH legacy est en place (clé publique, clé privée quand l'agent de 1Password n'est pas disponible, bloc de configuration non vide, ligne d'inclusion). Le constat MUST NOT nécessiter `sudo`, le réseau ni 1Password ; il ne vérifie donc ni chaque dépôt de l'arbre ni les domaines locaux, dont la commande de mise à jour se charge.

#### Scenario: Tout est en place
- **WHEN** les dépôts sont clonés et les prérequis du poste en place
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Accès legacy retiré
- **WHEN** le bloc de configuration SSH legacy a été supprimé
- **THEN** `module_check` retourne 1 et le module le rétablit

#### Scenario: Base de navigateur sans l'autorité
- **WHEN** une base de certificats de navigateur présente ne contient pas l'autorité de `mkcert`
- **THEN** `module_check` retourne 1
