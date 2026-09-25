## ADDED Requirements

### Requirement: Compte de travail, identité et agendas depuis 1Password
Lorsque le profil de Thunderbird ne porte aucun compte, le module SHALL y écrire, à partir de l'élément 1Password de Thunderbird, le compte Google de travail (réception IMAP sur `imap.gmail.com`, envoi SMTP sur `smtp.gmail.com`, authentification OAuth2), l'identité (nom, adresse, signature, réponse au-dessus de la citation, dossiers d'envoyés, de brouillons et d'archives de Gmail) et chaque agenda Google de l'élément (nom, couleur, lecture seule ou non, affiché ou masqué). Si Thunderbird n'a encore jamais été lancé, le module SHALL d'abord créer le profil que Thunderbird ouvrira. Les données personnelles (nom, adresse, signature, agendas) MUST NOT être versionnées dans le dépôt. Le module MUST NOT écrire dans un profil pendant que Thunderbird l'utilise, et MUST NOT réécrire ni compléter un compte déjà présent : une fois écrits, compte, identité et agendas appartiennent à l'utilisateur. Sans session 1Password, avec un élément sans nom ou sans adresse, avec Thunderbird resté ouvert, ou avec un profil qui porte déjà un autre compte, le module SHALL avertir, déclarer l'étape manuelle d'ajouter le compte et les agendas, et MUST NOT échouer.

#### Scenario: Premier passage
- **WHEN** le module s'exécute sur un poste où Thunderbird n'a jamais été lancé et qu'une session 1Password est active
- **THEN** à l'ouverture, Thunderbird montre le compte de travail avec son identité, sa signature et les dossiers Gmail, et les agendas de l'élément avec leurs couleurs, sans assistant de création de compte

#### Scenario: Compte déjà présent
- **WHEN** le profil porte déjà le compte Google de travail
- **THEN** rien n'est lu dans 1Password pour le compte et le profil n'est pas modifié

#### Scenario: Modifié par l'utilisateur
- **WHEN** l'utilisateur a changé sa signature ou masqué un agenda dans Thunderbird, puis relance le module
- **THEN** ses changements sont conservés

#### Scenario: Thunderbird ouvert
- **WHEN** Thunderbird est ouvert sur le profil et que l'utilisateur ne le ferme pas quand le module le demande
- **THEN** le profil n'est pas modifié, l'étape manuelle est déclarée et le module se termine sans erreur

#### Scenario: Autre compte présent
- **WHEN** le profil porte un compte de courriel, mais pas le compte Google de travail
- **THEN** le profil n'est pas modifié, l'étape manuelle est déclarée et le module se termine sans erreur

#### Scenario: Élément sans nom ou sans adresse
- **WHEN** l'élément 1Password de Thunderbird n'a pas de nom ou pas d'adresse
- **THEN** aucun profil n'est créé ni modifié, l'étape manuelle est déclarée et le module se termine sans erreur

#### Scenario: Profil impossible à créer
- **WHEN** Thunderbird n'a jamais été lancé et que la création de son profil échoue
- **THEN** le module échoue en le nommant, sans laisser Thunderbird en cours d'exécution

#### Scenario: Seulement les dossiers locaux
- **WHEN** le profil ne porte que les dossiers locaux (par exemple après la suppression du compte par l'utilisateur)
- **THEN** le module écrit le compte de travail, conserve les dossiers locaux et se termine sans étape manuelle à ce titre

#### Scenario: Session perdue pendant la lecture
- **WHEN** la session 1Password tombe pendant la lecture de l'élément
- **THEN** le profil n'est pas modifié, l'étape manuelle est déclarée et le module se termine sans erreur

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
`module_check` SHALL, en plus de l'installation, de la langue, de la commande, du lanceur et de la stratégie des dictionnaires, exiger que le profil de Thunderbird porte le compte Google de travail et une autorisation OAuth2 de Google, constatés sans `sudo`, sans réseau et sans 1Password. Tant que l'un manque, une relance SHALL reprendre l'étape qui manque sans retélécharger Thunderbird.

#### Scenario: Installé, sans compte
- **WHEN** Thunderbird est installé mais qu'aucun profil n'existe ou que le profil ne porte pas le compte
- **THEN** `module_check` retourne 1 et une relance écrit le compte sans rien télécharger

#### Scenario: Compte présent, pas connecté
- **WHEN** le profil porte le compte mais aucune autorisation OAuth2 de Google
- **THEN** `module_check` retourne 1 et une relance propose la connexion guidée sans réécrire le compte

#### Scenario: Tout est fait
- **WHEN** Thunderbird est installé et configuré, le compte présent et l'autorisation OAuth2 constatée
- **THEN** `module_check` retourne 0

## REMOVED Requirements

### Requirement: Comptes déclarés comme étape manuelle
**Reason**: Le compte, l'identité et les agendas sont écrits par le module depuis 1Password, et la connexion est guidée ; l'étape manuelle n'est plus déclarée que si l'un ou l'autre n'aboutit pas.
**Migration**: Poste où le compte a été ajouté à la main : `module_check` constate le compte ; seule la connexion OAuth2 est vérifiée.
