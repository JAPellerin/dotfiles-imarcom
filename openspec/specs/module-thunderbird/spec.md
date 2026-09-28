# module-thunderbird Specification

## Purpose

Installer Thunderbird, le client de courriel et d'agenda de l'utilisateur, depuis l'archive officielle de Mozilla, dans la langue d'Ubuntu, dans le dossier personnel de l'utilisateur pour que Thunderbird puisse se mettre à jour lui-même, avec une commande, un lanceur dans le menu des applications et les dictionnaires anglais (Canada) et français ; y écrire le compte Google de travail, l'identité et les agendas à partir de 1Password, puis guider la connexion Google : le module n'est « déjà fait » qu'une fois le compte présent et connecté.

## Requirements

### Requirement: Thunderbird depuis l'archive officielle de Mozilla, dans le dossier personnel
Le module `thunderbird` (groupe `apps`, dépend de `base`, de `shell` et de `1password`, nécessite une session graphique) SHALL installer la dernière version de Thunderbird dans la langue d'Ubuntu à partir de l'archive officielle publiée par Mozilla, dans un dossier appartenant à l'utilisateur, sans `sudo`, de sorte que la mise à jour intégrée de Thunderbird puisse écrire dans son dossier d'installation. Le module MUST NOT installer le snap de Thunderbird ni le paquet de transition d'Ubuntu, ni un paquet d'une source non officielle. Une installation existante dans la langue d'Ubuntu MUST NOT être retéléchargée ni écrasée. Un téléchargement ou une extraction en échec MUST faire échouer le module en le nommant, sans laisser de dossier d'installation incomplet.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Thunderbird
- **THEN** Thunderbird est installé dans le dossier personnel, appartient à l'utilisateur, et `thunderbird --version` répond

#### Scenario: Déjà installé
- **WHEN** Thunderbird est déjà installé à cet emplacement
- **THEN** rien n'est téléchargé et l'installation existante n'est pas modifiée

#### Scenario: Téléchargement en échec
- **WHEN** l'archive ne peut pas être téléchargée ou extraite
- **THEN** le module échoue en le nommant et aucun dossier d'installation partiel ne subsiste

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

#### Scenario: Lancé seul
- **WHEN** l'utilisateur lance `setup.sh thunderbird` sans autre module
- **THEN** le module `1password` est exécuté avant lui

### Requirement: Langue d'Ubuntu
Le module SHALL retenir la langue de Thunderbird d'après celle d'Ubuntu : la variante régionale si Mozilla la publie, sinon la langue sans région, sinon l'anglais (États-Unis). `module_check` SHALL constater, sans réseau, que la langue de l'installation est celle retenue. Une installation dans une autre langue SHALL être remplacée par la version de la langue retenue sans toucher au profil de l'utilisateur. Une archive dont la langue n'est pas celle demandée MUST faire échouer le module en le nommant, sans remplacer l'installation existante.

#### Scenario: Ubuntu en français du Canada
- **WHEN** Ubuntu est en `fr_CA.UTF-8`
- **THEN** le module installe la version française de Thunderbird (Mozilla ne publie pas de `fr-CA`)

#### Scenario: Ubuntu en anglais
- **WHEN** Ubuntu est en `en_CA.UTF-8` ou en `en_US.UTF-8`
- **THEN** le module installe respectivement la version `en-CA` ou `en-US`

#### Scenario: Langue d'Ubuntu changée
- **WHEN** Thunderbird est installé dans une autre langue que celle d'Ubuntu
- **THEN** `module_check` retourne 1, le module réinstalle Thunderbird dans la langue d'Ubuntu et le profil de l'utilisateur est intact

#### Scenario: Archive dans une autre langue
- **WHEN** l'archive téléchargée n'est pas dans la langue demandée
- **THEN** le module échoue en le nommant et l'installation existante est conservée

### Requirement: Dictionnaires anglais (Canada) et français
Le module SHALL déployer la stratégie d'entreprise versionnée dans le dépôt, qui fait installer d'office par Thunderbird les dictionnaires anglais (Canada) et français (Dicollecte) depuis addons.thunderbird.net sans empêcher l'utilisateur de les désactiver, dans le dossier système des stratégies de Thunderbird, par le helper de fichiers système du socle. `module_check` SHALL constater que la stratégie déployée est identique à celle du dépôt. Une relance sans changement MUST NOT appeler `sudo`.

#### Scenario: Premier démarrage
- **WHEN** l'utilisateur ouvre Thunderbird après le module
- **THEN** les dictionnaires anglais (Canada) et français sont installés et proposés pour la vérification orthographique

#### Scenario: Stratégie retirée ou différente
- **WHEN** la stratégie a été supprimée ou modifiée
- **THEN** `module_check` retourne 1 et le module la réécrit

### Requirement: Commande et lanceur
Le module SHALL rendre la commande `thunderbird` disponible dans `~/.local/bin` et SHALL déposer dans `~/.local/share/applications` un lanceur tiré du fichier de bureau que publie Mozilla, dont la commande et l'icône désignent l'installation du dossier personnel. `module_check` SHALL constater la commande et le lanceur.

#### Scenario: Lanceur dans le menu
- **WHEN** le module se termine
- **THEN** Thunderbird apparaît dans le menu des applications avec son icône, et s'ouvre depuis ce menu

#### Scenario: Lanceur retiré
- **WHEN** le lanceur a été supprimé
- **THEN** `module_check` retourne 1 et le module le rétablit sans retélécharger Thunderbird

### Requirement: Compte de travail, identité et agendas depuis 1Password
Lorsque le profil de Thunderbird ne porte aucun compte de courriel (les dossiers locaux ne comptent pas), le module SHALL y écrire, à partir de l'élément 1Password de Thunderbird, le compte Google de travail — un compte Gmail à l'adresse du domaine de l'entreprise, `@imarcom.net` — (réception IMAP sur `imap.gmail.com`, envoi SMTP sur `smtp.gmail.com`, authentification OAuth2), l'identité (nom, adresse, signature HTML placée sous la réponse et au-dessus de la citation, réponse au-dessus de la citation, dossiers d'envoyés, de brouillons et d'archives de Gmail) et chaque agenda Google de l'élément (nom, couleur, lecture seule ou non, affiché ou masqué), dans l'ordre de l'élément, l'agenda Google de l'adresse de travail devenant l'agenda par défaut des nouveaux événements, à la place de tout agenda du profil qui l'était, et les agendas déjà présents dans le profil étant gardés à la suite ; Thunderbird MUST NOT demander, au premier démarrage, à devenir l'application de courriel par défaut. Si Thunderbird n'a encore jamais été lancé, le module SHALL d'abord créer le profil que Thunderbird ouvrira. Les données personnelles (nom, adresse, signature, agendas) MUST NOT être versionnées dans le dépôt. Le module MUST NOT écrire dans un profil pendant que Thunderbird l'utilise, MUST NOT poser de question à l'utilisateur pour écrire le compte (le parcours de connexion garde les siennes), et MUST NOT réécrire ni compléter un compte déjà présent : une fois écrits, compte, identité et agendas appartiennent à l'utilisateur. Le module MUST NOT écrire un compte incomplet : si la session 1Password tombe ou qu'une lecture échoue pour une autre raison qu'un champ absent, rien n'est écrit. Sans session 1Password, avec un élément sans nom ou sans adresse, avec une adresse hors du domaine de l'entreprise, avec une lecture en échec, avec plusieurs installations de Thunderbird sur le poste, ou avec un profil qui porte déjà un autre compte (y compris un compte Gmail hors du domaine de l'entreprise), le module SHALL avertir, déclarer l'étape manuelle d'ajouter le compte et les agendas, et MUST NOT échouer ; avec Thunderbird ouvert, il SHALL déclarer l'étape manuelle de fermer Thunderbird et de relancer le module.

#### Scenario: Premier passage
- **WHEN** le module s'exécute sur un poste où Thunderbird n'a jamais été lancé et qu'une session 1Password est active
- **THEN** à l'ouverture, Thunderbird montre le compte de travail avec son identité, sa signature et les dossiers Gmail, et les agendas de l'élément avec leurs couleurs et dans leur ordre, sans assistant de création de compte ; une réponse place la signature sous le texte de l'utilisateur, au-dessus de la citation, et un nouvel événement va dans l'agenda Google de l'adresse de travail

#### Scenario: Compte déjà présent
- **WHEN** le profil porte déjà le compte Google de travail
- **THEN** rien n'est lu dans 1Password pour le compte et le profil n'est pas modifié

#### Scenario: Modifié par l'utilisateur
- **WHEN** l'utilisateur a changé sa signature ou masqué un agenda dans Thunderbird, puis relance le module
- **THEN** ses changements sont conservés

#### Scenario: Thunderbird ouvert
- **WHEN** Thunderbird est ouvert sur le profil au moment d'écrire le compte
- **THEN** aucune question n'est posée, rien n'est lu dans 1Password, le profil n'est pas modifié, l'étape manuelle demande de fermer Thunderbird et de relancer le module, le module se termine sans erreur et `module_check` retourne 1

#### Scenario: Autre compte présent
- **WHEN** le profil porte un compte de courriel, mais pas le compte Google de travail (par exemple un compte Gmail personnel)
- **THEN** rien n'est lu dans 1Password, le profil n'est pas modifié, l'étape manuelle est déclarée et le module se termine sans erreur

#### Scenario: Élément sans nom ou sans adresse
- **WHEN** l'élément 1Password de Thunderbird n'a pas de nom ou pas d'adresse
- **THEN** aucun profil n'est créé ni modifié, l'étape manuelle est déclarée et le module se termine sans erreur

#### Scenario: Adresse hors du domaine de l'entreprise
- **WHEN** l'adresse de l'élément 1Password de Thunderbird n'est pas du domaine de l'entreprise
- **THEN** rien n'est écrit, le module avertit, déclare l'étape manuelle et se termine sans erreur

#### Scenario: Profil impossible à créer
- **WHEN** Thunderbird n'a jamais été lancé et que la création de son profil échoue
- **THEN** le module échoue en le nommant, sans laisser Thunderbird en cours d'exécution

#### Scenario: Seulement les dossiers locaux
- **WHEN** le profil ne porte que les dossiers locaux (par exemple après la suppression du compte par l'utilisateur)
- **THEN** le module écrit le compte de travail, conserve les dossiers locaux et se termine sans étape manuelle à ce titre

#### Scenario: Profil déjà démarré, avec son agenda local
- **WHEN** le profil, sans compte de courriel, porte déjà un agenda local par défaut
- **THEN** le module écrit les agendas de l'élément en tête, garde l'agenda local à leur suite, et seul l'agenda de l'adresse de travail reste l'agenda par défaut

#### Scenario: Profil inscrit dont le dossier a disparu
- **WHEN** Thunderbird désigne un profil dont le dossier n'existe plus
- **THEN** le module crée le profil comme au premier lancement, puis y écrit le compte de travail

#### Scenario: Session perdue pendant la lecture
- **WHEN** la session 1Password tombe, ou une lecture échoue pour une autre raison qu'un champ absent, pendant la lecture de l'élément
- **THEN** le profil n'est pas modifié, l'étape manuelle est déclarée et le module se termine sans erreur

#### Scenario: Plusieurs installations de Thunderbird
- **WHEN** plusieurs installations de Thunderbird sont inscrites sur le poste
- **THEN** rien n'est lu dans 1Password, aucun profil n'est modifié, l'étape manuelle est déclarée et le module se termine sans erreur ; `module_check` retourne 1 sans rien afficher

#### Scenario: Sans session 1Password
- **WHEN** aucune session 1Password n'est active et que le profil ne porte aucun compte
- **THEN** aucun profil n'est créé ni modifié, l'étape manuelle est déclarée et le module se termine sans erreur

### Requirement: Connexion Google guidée
Une fois le compte présent, le module SHALL lancer le parcours de connexion guidée du socle : adresse de travail affichée, mot de passe Google Workspace de travail lu dans 1Password et copié dans le presse-papiers, Thunderbird ouvert, consigne de se connecter dans la fenêtre Google de Thunderbird, puis attente. La connexion SHALL être constatée, sans `sudo`, sans réseau et sans 1Password, par la présence d'une autorisation OAuth2 de Google dans le profil, par la même sonde dans le parcours et dans `module_check`. Le mot de passe MUST NOT apparaître à l'écran ni dans le journal. Si le parcours n'aboutit pas, le module SHALL déclarer l'étape manuelle, MUST NOT échouer, et reste à faire.

#### Scenario: Connexion guidée réussie
- **WHEN** l'utilisateur colle le mot de passe dans la fenêtre Google ouverte par Thunderbird et autorise Thunderbird
- **THEN** l'autorisation est constatée dans le profil, le presse-papiers est vidé, aucune étape manuelle n'est déclarée, courriels et agendas se chargent, et le mot de passe ne figure ni dans la sortie du script ni dans son journal, alors que l'adresse y est affichée

#### Scenario: Déjà connecté
- **WHEN** le profil porte le compte et une autorisation OAuth2 de Google
- **THEN** aucune lecture dans 1Password n'a lieu et Thunderbird n'est pas ouvert

#### Scenario: Passer
- **WHEN** l'utilisateur passe l'étape de connexion
- **THEN** le presse-papiers est vidé, l'étape manuelle déclarée demande de se connecter au compte (et non de l'ajouter) et le module se termine sans erreur

### Requirement: État du module avec compte et connexion
`module_check` SHALL, en plus de l'installation, de la langue, de la commande, du lanceur et de la stratégie des dictionnaires, exiger que le profil de Thunderbird porte le compte Google de travail et une autorisation OAuth2 de Google, constatés sans `sudo`, sans réseau et sans 1Password ; le compte de travail est reconnu à son serveur `imap.gmail.com` et à son adresse du domaine de l'entreprise. Tant que l'un manque, une relance SHALL reprendre l'étape qui manque sans retélécharger Thunderbird.

#### Scenario: Installé, sans compte
- **WHEN** Thunderbird est installé mais qu'aucun profil n'existe ou que le profil ne porte pas le compte
- **THEN** `module_check` retourne 1 et une relance écrit le compte sans rien télécharger

#### Scenario: Compte présent, pas connecté
- **WHEN** le profil porte le compte mais aucune autorisation OAuth2 de Google
- **THEN** `module_check` retourne 1 et une relance propose la connexion guidée sans réécrire le compte

#### Scenario: Tout est fait
- **WHEN** Thunderbird est installé et configuré, le compte présent et l'autorisation OAuth2 constatée
- **THEN** `module_check` retourne 0
