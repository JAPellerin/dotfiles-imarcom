# module-contract Specification

## Purpose

Définir la forme obligatoire d'un module pour que le runner puisse le découvrir, afficher son état, résoudre ses dépendances et l'exécuter de façon idempotente ; tout module présent ou futur MUST s'y conformer.

## Requirements

### Requirement: Un fichier par module, découvert automatiquement
Chaque module SHALL être un fichier `modules/NN-<nom>.sh` où `NN` est un préfixe numérique à deux chiffres servant d'ordre d'affichage par défaut et `<nom>` l'identifiant du module (kebab-case). Le runner SHALL découvrir les modules en listant ce dossier, sans registre à maintenir à la main.

#### Scenario: Ajout d'un module
- **WHEN** un nouveau fichier `modules/40-node.sh` conforme est ajouté
- **THEN** il apparaît dans `setup.sh --list` et dans le menu sans autre modification

### Requirement: Métadonnées obligatoires
Chaque module SHALL déclarer `MODULE_NAME` (identique au `<nom>` du fichier), `MODULE_DESC` (une ligne, en français), `MODULE_GROUP` (un mot en kebab-case parmi `systeme`, `shell`, `dev`, `apps`, `bureau`, `projets`, affiché en préfixe dans le menu) et `MODULE_DEPS` (liste de noms de modules, possiblement vide). Il MAY déclarer `MODULE_NEEDS_GUI=1` s'il nécessite une session graphique. Un module dont les métadonnées obligatoires manquent ou dont `MODULE_NAME` diffère du nom de fichier MUST être rejeté par le runner avec un message nommant le fichier.

#### Scenario: Module invalide
- **WHEN** `modules/50-navigateur.sh` ne déclare pas `MODULE_DESC`
- **THEN** `setup.sh` signale le fichier et le champ manquant, et refuse de démarrer

### Requirement: Fonctions du cycle de vie
Chaque module SHALL définir trois fonctions : `module_check` (retourne 0 si le module est déjà appliqué, 1 sinon, sans rien modifier), `module_install` (installe les logiciels) et `module_configure` (applique la configuration, y compris les secrets). Le runner SHALL appeler `module_check` avant l'exécution et sauter le module s'il retourne 0, puis `module_install` et `module_configure` dans cet ordre.

#### Scenario: Module déjà appliqué
- **WHEN** `module_check` retourne 0
- **THEN** `module_install` et `module_configure` ne sont pas appelées et le module est marqué « déjà fait »

#### Scenario: Application complète
- **WHEN** `module_check` retourne 1
- **THEN** `module_install` puis `module_configure` sont appelées ; si l'une échoue, le module est marqué « échoué »

### Requirement: Idempotence
`module_install` et `module_configure` MUST pouvoir être réexécutées sur une machine où le module est partiellement ou totalement appliqué sans erreur ni duplication (dépôt apt ajouté deux fois, ligne dupliquée dans un fichier de config, etc.).

#### Scenario: Réexécution forcée
- **WHEN** un module déjà appliqué est réexécuté (ex. après un échec partiel corrigé à la main)
- **THEN** il se termine sans erreur et l'état final est identique à une première application

### Requirement: Interactivité et choix
Un module MAY poser des questions à l'utilisateur (choix d'options, confirmation) via les helpers d'interface fournis par le socle. Ces questions SHALL être posées au début de `module_install`, avant toute action longue, pour que l'utilisateur ne soit pas sollicité au milieu d'une installation. Comme l'état n'est pas persisté, un module à choix interne SHALL considérer dans `module_check` qu'il reste à faire et n'installer, à chaque exécution, que ce qui manque parmi les options choisies. Ce cas est l'exception : une application de bureau a en règle générale son propre module, et le choix se fait dans le menu principal.

#### Scenario: Module avec options
- **WHEN** le module `navigateur` propose Brave, Chrome et Firefox
- **THEN** la sélection est demandée avant le premier `apt install`, puis les installations s'enchaînent sans nouvelle question

#### Scenario: Relance d'un module à choix interne
- **WHEN** Brave est déjà installé et l'utilisateur relance `navigateur` en choisissant Brave et Firefox
- **THEN** seul Firefox est installé et le module se termine sans erreur

### Requirement: Déclaration des étapes manuelles
Un module SHALL pouvoir déclarer, via un helper du socle, une ou plusieurs étapes manuelles que le script ne peut pas automatiser ; le runner les reprend dans le résumé final.

#### Scenario: Étape manuelle déclarée
- **WHEN** le module `1password` déclare « Activer l'agent SSH : Settings > Developer »
- **THEN** cette ligne figure dans la section « Étapes manuelles restantes » du résumé final

### Requirement: Accès aux helpers du socle
Un module SHALL pouvoir utiliser les helpers du socle pour : journaliser, exécuter une commande avec `sudo`, ajouter un dépôt apt avec sa clé GPG (fichier `.sources` deb822, clé dans `/etc/apt/keyrings/`), installer des paquets apt, installer un paquet `.deb` téléchargé depuis une URL, installer une police depuis une archive ou des fichiers de police, lire un secret 1Password, poser une question ou un choix à l'utilisateur, et savoir si une session graphique est disponible. Un module MUST NOT appeler `gum` ni `apt` directement quand un helper existe pour l'opération, ni télécharger et installer un `.deb` ou une police par ses propres moyens.

#### Scenario: Ajout de dépôt apt
- **WHEN** un module ajoute le dépôt Docker via le helper avec l'URL de la clé et l'URL du dépôt
- **THEN** la clé est écrite dans `/etc/apt/keyrings/`, le fichier `.sources` est créé une seule fois et `apt update` est exécuté

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

### Requirement: URL d'un fichier publié dans les releases GitHub
Le socle SHALL fournir un helper qui, pour un dépôt GitHub et un motif de nom de fichier, renvoie l'URL de téléchargement du fichier correspondant dans **la plus récente des releases publiées qui en contient un**. Les brouillons et les préversions MUST être écartés. Une release récente qui ne contient aucun fichier correspondant MUST être sautée au profit de la précédente. Si aucune release ne contient un tel fichier, ou si l'API de GitHub ne répond pas, le helper MUST échouer en nommant le dépôt et le motif, sans rien imprimer sur sa sortie standard. Un motif invalide MUST être signalé comme tel, avant tout appel à l'API. Le helper MUST NOT laisser de fichier temporaire, y compris appelé dans une substitution de commande.

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
- **THEN** le helper échoue en nommant le dépôt, le motif et la cause rapportée par `curl`

#### Scenario: Motif invalide
- **WHEN** le motif n'est pas une expression régulière valide
- **THEN** le helper échoue en disant que le motif est invalide, sans interroger l'API

### Requirement: Connexion guidée par 1Password
Le socle SHALL fournir un helper de connexion guidée, pour les applications qui n'acceptent pas de connexion scriptée. Le module lui fournit une sonde qui constate, sans `sudo` ni réseau, que la connexion est faite ; un libellé ; le texte de l'étape manuelle ; et, au choix, un secret à copier (référence 1Password, ou valeur produite par une fonction du module), un identifiant à afficher, une commande qui ouvre l'application et une consigne. Si la sonde réussit d'emblée, le helper MUST NOT lire de secret, ouvrir de fenêtre ni appeler `sudo`. Sinon, il SHALL copier le secret dans le presse-papiers, afficher l'identifiant et la consigne, ouvrir l'application, puis attendre que la sonde réussisse ; au délai écoulé, il SHALL proposer de continuer d'attendre ou de passer. Le secret MUST NOT apparaître à l'écran ni dans le journal. Le presse-papiers MUST être vidé à la fin du parcours dans tous les cas : connexion constatée, étape passée ou script interrompu. Le helper MUST NOT faire échouer le module : sans session 1Password, avec un secret illisible ou un presse-papiers indisponible, ou quand l'utilisateur passe, il SHALL avertir et déclarer l'étape manuelle, puis rendre la main sans erreur. Un module dont l'état attendu comprend cette connexion SHALL inclure la même sonde dans `module_check` et SHALL lancer le parcours dans `module_configure`, après l'installation et la configuration de l'application : tant que la connexion n'est pas faite, le module reste à faire et une relance repropose le parcours.

#### Scenario: Déjà connecté
- **WHEN** la sonde réussit au début du parcours
- **THEN** le helper le signale et se termine, sans lecture dans 1Password, sans fenêtre ouverte et sans `sudo`

#### Scenario: Connexion faite pendant l'attente
- **WHEN** une session 1Password est active, le helper copie le mot de passe, ouvre l'application, et l'utilisateur se connecte
- **THEN** la sonde réussit, le presse-papiers est vidé et aucune étape manuelle n'est déclarée

#### Scenario: Passer
- **WHEN** le délai s'écoule et l'utilisateur choisit de passer
- **THEN** le presse-papiers est vidé, l'étape manuelle est déclarée et le module continue sans erreur

#### Scenario: Interruption
- **WHEN** l'utilisateur interrompt le script pendant l'attente
- **THEN** le presse-papiers est vidé

#### Scenario: Sans session 1Password
- **WHEN** aucune session `op` n'est active et un secret est demandé
- **THEN** le helper avertit, déclare l'étape manuelle, n'ouvre aucune fenêtre et se termine sans erreur

#### Scenario: Connexion passée, module toujours à faire
- **WHEN** l'utilisateur a passé l'étape de connexion d'un module qui emploie le helper
- **THEN** `module_check` de ce module retourne 1 et une relance propose de nouveau le parcours, sans réinstaller l'application

#### Scenario: Secret jamais visible
- **WHEN** le helper copie un mot de passe lu dans 1Password
- **THEN** la valeur ne figure ni dans la sortie du script ni dans son journal, alors que l'identifiant fourni y est affiché

### Requirement: Ouverture détachée d'une application
Le socle SHALL fournir un helper qui lance une application graphique détachée du script : le script n'attend pas l'application, celle-ci n'hérite ni du terminal ni du journal, et la commande lancée est consignée au journal. Si l'application ne peut pas être lancée, le helper SHALL avertir sans faire échouer le module.

#### Scenario: Application lancée
- **WHEN** un module ouvre une application par le helper
- **THEN** le script reprend aussitôt, le journal consigne la commande et ne reçoit aucune sortie de l'application

#### Scenario: Application introuvable
- **WHEN** la commande à lancer n'existe pas
- **THEN** le helper avertit et le module continue sans erreur
