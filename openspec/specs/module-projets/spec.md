# module-projets Specification

## Purpose

Amener sur le poste les dépôts de travail de l'utilisateur, aux mêmes emplacements que sur son poste de référence, avec ce que leurs projets demandent au poste et ne peuvent pas poser eux-mêmes (autorité de certification locale, domaines locaux, hôtes SSH connus, accès SSH à l'hôte legacy) ; relever ces dépôts sur le poste de référence et les tenir à jour par des commandes du runner. Tout ce qui est propre aux projets vit dans 1Password, jamais dans le dépôt public.

## Requirements

### Requirement: Aucune donnée propre aux projets dans le dépôt
Les noms de dépôts, les URL, les domaines locaux, les noms d'hôtes et les identifiants propres aux projets de l'utilisateur MUST NOT figurer dans le dépôt du script : le module SHALL les lire dans 1Password, dans l'élément des projets (`op://Imarcom/Projets`) et dans l'élément de la clé SSH legacy (`op://Private/Legacy SSH`), et SHALL ne les montrer que dans ses messages de progression et son journal.

#### Scenario: Dépôt du script
- **WHEN** on cherche dans le dépôt du script un nom de dépôt, un domaine local ou un hôte propre aux projets de l'utilisateur
- **THEN** on ne le trouve pas : seules y figurent les références aux éléments 1Password

### Requirement: Dépôts clonés d'après l'arbre de 1Password
Le module `projets` (groupe `projets`, dépend de `base`, `1password` et `git`, sans session graphique requise) SHALL lire l'arbre des dépôts — une ligne par dépôt : chemin relatif au dossier personnel et URL du dépôt — dans l'élément des projets, et SHALL cloner chaque dépôt absent à son chemin. Un chemin MUST se trouver sous `~/projets` ; une ligne dont le chemin sort de ce dossier, est absolu, ou dont l'URL n'est pas celle d'un dépôt git distant MUST être refusée en la nommant, sans rien écrire pour elle. Un dossier existant qui est un clone du même dépôt MUST NOT être modifié ; un dossier existant qui n'en est pas un MUST faire échouer le module en le nommant, sans y toucher. Le clonage MUST NOT poser de question (hôte inconnu, identifiants) : il réussit ou échoue. Un clonage en échec MUST faire échouer le module en nommant le dépôt, après avoir tenté les autres. Pour chaque dépôt qu'il vient de cloner et qui prévoit une commande de préparation `make setup`, le module SHALL déclarer l'étape manuelle de la lancer dans ce dépôt. Sans session 1Password, avec un élément illisible ou un arbre vide, le module SHALL déclarer l'étape manuelle de relever les projets sur le poste de référence, MUST NOT échouer et reste à faire tant qu'aucun dépôt n'est cloné.

#### Scenario: Poste neuf
- **WHEN** l'arbre de 1Password liste des dépôts et qu'aucun n'est cloné
- **THEN** chaque dépôt est cloné à son chemin sous `~/projets`, et le résumé final demande de lancer `make setup` dans chacun de ceux qui en ont un

#### Scenario: Clone existant
- **WHEN** un dépôt de l'arbre est déjà cloné, avec des modifications en cours sur une branche de travail
- **THEN** le dépôt n'est ni modifié ni mis à jour, et aucune étape `make setup` n'est déclarée pour lui

#### Scenario: Dossier étranger
- **WHEN** le chemin d'un dépôt de l'arbre est occupé par un dossier qui n'est pas un clone de ce dépôt
- **THEN** le module échoue en nommant ce chemin, qui reste intact, et clone quand même les autres dépôts

#### Scenario: Ligne refusée
- **WHEN** une ligne de l'arbre désigne un chemin hors de `~/projets` ou contient `..`
- **THEN** le module avertit en nommant la ligne, n'écrit rien pour elle et traite les autres

#### Scenario: Sans session 1Password
- **WHEN** aucune session 1Password n'est active et qu'aucun dépôt n'est cloné
- **THEN** le résumé final demande de relever les projets et d'ouvrir une session, le module se termine sans erreur et `module_check` retourne 1

### Requirement: Hôte Bitbucket connu
Le module SHALL ajouter `bitbucket.org` aux hôtes SSH connus de l'utilisateur, avec les clés que publie Bitbucket, sans doublon, pour que les clonages ne posent pas de question. Les clés déjà présentes MUST NOT être dupliquées.

#### Scenario: Premier passage
- **WHEN** `bitbucket.org` n'est pas dans les hôtes connus
- **THEN** ses clés publiées y sont ajoutées et un clonage depuis Bitbucket ne demande pas de confirmer l'hôte

### Requirement: Autorité de certification locale
Le module SHALL installer `mkcert` et `libnss3-tools` depuis les dépôts d'Ubuntu et SHALL installer l'autorité de certification locale de `mkcert` dans le magasin du système, pour que les certificats de développement des projets soient reconnus. Une autorité déjà installée MUST NOT être recréée.

#### Scenario: Premier passage
- **WHEN** le module s'exécute sur un poste sans `mkcert`
- **THEN** `mkcert` est installé, son autorité existe et figure dans le magasin de certificats du système

#### Scenario: Réexécution
- **WHEN** l'autorité existe déjà
- **THEN** elle est conservée telle quelle

### Requirement: Domaines locaux des projets
Le module SHALL ajouter à `/etc/hosts`, pour chaque domaine listé dans le champ `hosts` de l'élément des projets (séparés par des sauts de ligne, des espaces ou des virgules), une ligne qui le fait pointer sur `127.0.0.1`, lorsque aucune ligne active ne nomme déjà ce domaine. Les lignes existantes MUST NOT être modifiées ni supprimées. Un domaine qui n'a pas la forme d'un nom d'hôte MUST être refusé en le nommant. Un champ absent ou vide MUST NOT être une erreur.

#### Scenario: Domaine ajouté
- **WHEN** un domaine du champ `hosts` n'est pas dans `/etc/hosts`
- **THEN** `/etc/hosts` contient une ligne qui le fait pointer sur `127.0.0.1`, et ses autres lignes sont inchangées

#### Scenario: Domaine déjà présent
- **WHEN** une ligne active de `/etc/hosts` nomme déjà le domaine, quelle que soit son adresse
- **THEN** rien n'est ajouté pour lui

### Requirement: Accès SSH à l'hôte legacy
Le module SHALL rendre l'hôte legacy joignable par SSH avec la clé de l'élément `op://Private/Legacy SSH` (coffre dont l'agent de 1Password sert les clés sans configuration) : clé publique toujours écrite dans `~/.ssh/id_ed25519_legacy.pub` ; clé privée écrite dans `~/.ssh/id_ed25519_legacy`, lisible par l'utilisateur seul, **seulement** quand l'agent SSH de l'application 1Password n'est pas disponible ; bloc de configuration SSH tiré de la note de l'élément, écrit dans `~/.ssh/config.d/projets.conf` ; `~/.ssh/config` SHALL inclure les fichiers de `~/.ssh/config.d/` par une ligne placée avant tout bloc `Host`, les autres lignes de `~/.ssh/config` MUST NOT être modifiées. La clé privée MUST NOT apparaître à l'écran ni dans le journal. Un élément absent ou incomplet SHALL faire déclarer l'étape manuelle d'importer la clé legacy dans 1Password, sans échec.

#### Scenario: Poste avec l'application 1Password
- **WHEN** l'agent de 1Password sert les clés SSH
- **THEN** seule la clé publique est écrite, le bloc de configuration est en place, et `ssh` vers l'hôte legacy propose la clé servie par l'agent

#### Scenario: Poste sans l'application (WSL)
- **WHEN** l'agent de 1Password n'est pas disponible
- **THEN** la clé privée est écrite en 0600 à côté de la clé publique, et la clé privée ne figure ni dans la sortie ni dans le journal

#### Scenario: Configuration SSH existante
- **WHEN** `~/.ssh/config` contient déjà des blocs `Host`
- **THEN** la ligne d'inclusion est ajoutée avant le premier bloc, une seule fois, et les blocs existants sont inchangés

#### Scenario: Élément absent
- **WHEN** l'élément de la clé legacy n'existe pas dans 1Password
- **THEN** le résumé final demande de l'importer, et le module se termine sans erreur

### Requirement: Relevé des projets
La commande de relevé du runner SHALL parcourir `~/projets`, relever chaque dépôt git (sans descendre dans un dépôt) avec son chemin relatif au dossier personnel et l'URL de son dépôt `origin`, et SHALL écrire cet arbre, trié, dans l'élément des projets, en créant l'élément s'il n'existe pas et sans toucher à ses autres champs. Un dépôt sans `origin` SHALL être signalé et laissé hors de l'arbre. L'élément MUST NOT être réécrit si l'arbre n'a pas changé. Aucun dépôt MUST NOT être modifié.

#### Scenario: Relevé
- **WHEN** l'utilisateur lance le relevé sur son poste de référence
- **THEN** l'élément des projets contient une ligne par dépôt git sous `~/projets`, avec son `origin`, le champ `hosts` est inchangé, et le runner affiche le nombre de dépôts relevés

#### Scenario: Dépôt sans origin
- **WHEN** un dépôt sous `~/projets` n'a pas de dépôt `origin`
- **THEN** le relevé le nomme dans un avertissement et ne l'inscrit pas

### Requirement: Mise à jour des projets
La commande de mise à jour du runner SHALL relire l'arbre dans 1Password, cloner les dépôts absents comme le module, ajouter les domaines locaux manquants, puis, pour chaque dépôt déjà cloné, récupérer l'état du dépôt distant et avancer la branche courante jusqu'à sa branche suivie **seulement** si l'arbre de travail est propre et que l'avance est rapide. Un dépôt avec des modifications en cours sur des fichiers suivis, une branche sans branche suivie ou une branche qui a divergé MUST NOT être modifié : il SHALL être listé avec la raison. Aucune opération MUST NOT poser de question. La commande SHALL finir sur un bilan (mis à jour, déjà à jour, clonés, laissés de côté) et MUST retourner un code non nul si un clonage ou une récupération a échoué.

#### Scenario: Dépôt en retard
- **WHEN** un dépôt propre suit une branche distante qui a avancé
- **THEN** sa branche courante avance jusqu'à elle et le bilan le compte parmi les mis à jour

#### Scenario: Modifications en cours
- **WHEN** un dépôt a des modifications non validées sur des fichiers suivis
- **THEN** son arbre de travail et sa branche sont inchangés, et le bilan le nomme avec la raison

#### Scenario: Dépôt ajouté à l'arbre
- **WHEN** l'arbre contient un dépôt absent du poste
- **THEN** il est cloné et le bilan le compte parmi les clonés

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si au moins un dépôt git existe sous `~/projets`, que `bitbucket.org` est un hôte connu, que `mkcert` et `libnss3-tools` sont installés et l'autorité de `mkcert` présente, et que l'accès SSH legacy est en place (clé publique, clé privée quand l'agent de 1Password n'est pas disponible, bloc de configuration non vide, ligne d'inclusion). Le constat MUST NOT nécessiter `sudo`, le réseau ni 1Password ; il ne vérifie donc ni chaque dépôt de l'arbre ni les domaines locaux, dont la commande de mise à jour se charge.

#### Scenario: Tout est en place
- **WHEN** les dépôts sont clonés et les prérequis du poste en place
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Accès legacy retiré
- **WHEN** le bloc de configuration SSH legacy a été supprimé
- **THEN** `module_check` retourne 1 et le module le rétablit
