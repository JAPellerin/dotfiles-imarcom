## MODIFIED Requirements

### Requirement: Client Rocket.Chat depuis son .deb officiel le plus récent
Le module `rocketchat` (groupe `apps`, dépend de `base` et de `1password`, nécessite une session graphique) SHALL installer le paquet `rocketchat` à partir du `.deb` amd64 publié par l'éditeur dans ses releases GitHub, en retenant la plus récente des releases publiées qui en contient un, par les helpers du socle. Un paquet déjà installé MUST NOT être retéléchargé ni réinstallé. L'échec de la recherche ou du téléchargement MUST faire échouer le module en le nommant.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans client Rocket.Chat
- **THEN** le paquet `rocketchat` est installé et son lanceur est présent dans le menu des applications

#### Scenario: Déjà installé
- **WHEN** le paquet `rocketchat` est installé, le serveur pré-configuré et l'utilisateur connecté à `rocketchat.imarcom.net`
- **THEN** `module_check` retourne 0 et rien n'est téléchargé

#### Scenario: Installé, pas encore connecté
- **WHEN** le paquet `rocketchat` est installé et le serveur pré-configuré, mais l'utilisateur n'est pas connecté
- **THEN** `module_check` retourne 1 et une relance propose la connexion guidée sans rien télécharger ni réinstaller

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

#### Scenario: Lancé seul
- **WHEN** l'utilisateur lance `setup.sh rocketchat` sans autre module
- **THEN** le module `1password` est exécuté avant lui

### Requirement: Serveur de l'entreprise pré-configuré
Le module SHALL déployer la liste de serveurs par défaut versionnée dans le dépôt, qui désigne `https://rocketchat.imarcom.net`, dans le dossier des ressources du paquet, emplacement que documente Rocket.Chat pour Linux et que le client relit sans jamais supprimer le fichier, par le helper de fichiers système du socle. Au premier lancement du client, le serveur de l'entreprise SHALL être proposé sans que l'utilisateur ait à saisir son adresse. Le module MUST NOT empêcher l'utilisateur d'ajouter d'autres serveurs. `module_check` SHALL constater que le fichier déployé est identique à celui du dépôt.

#### Scenario: Premier lancement
- **WHEN** l'utilisateur ouvre le client après le module, sur un poste où aucun serveur n'a encore été ajouté
- **THEN** le client s'ouvre sur la page de connexion de `rocketchat.imarcom.net`

#### Scenario: Après le premier lancement
- **WHEN** le client a été ouvert une fois après le module
- **THEN** la liste de serveurs déployée est toujours en place, identique à celle du dépôt

#### Scenario: Fichier différent
- **WHEN** un fichier de serveurs au contenu différent existe à cet emplacement
- **THEN** `module_check` retourne 1 et le module le remplace par la version du dépôt

#### Scenario: Fichier retiré
- **WHEN** la liste de serveurs a été supprimée
- **THEN** `module_check` retourne 1 et le module la réécrit

### Requirement: Profil AppArmor qui permet au client de démarrer
Le module SHALL déployer le profil AppArmor versionné dans le dépôt, qui autorise les espaces de noms utilisateur au binaire du client, dans `/etc/apparmor.d/` sous un nom que les scripts de maintenance du paquet ne suppriment pas, par le helper de fichiers système du socle, et SHALL le charger dans le noyau lorsqu'il vient de l'écrire. Une relance sans changement MUST NOT recharger le profil. Si le chargement échoue, le module MUST échouer et le profil MUST NOT être laissé en place. `module_check` SHALL constater que le profil déployé est identique à celui du dépôt.

#### Scenario: Premier lancement sous Ubuntu 26.04
- **WHEN** l'utilisateur ouvre le client après le module, sur un système qui restreint les espaces de noms utilisateur non privilégiés
- **THEN** le client démarre sans plantage

#### Scenario: Profil retiré ou différent
- **WHEN** le profil a été supprimé ou modifié
- **THEN** `module_check` retourne 1 et le module réécrit puis recharge la version du dépôt

#### Scenario: Mise à jour du client
- **WHEN** le paquet `rocketchat` est mis à jour ou rétrogradé après le module, l'utilisateur étant connecté à `rocketchat.imarcom.net`
- **THEN** le profil déployé est toujours en place et `module_check` retourne 0

#### Scenario: Chargement en échec
- **WHEN** le chargement du profil échoue
- **THEN** le module échoue, le profil est retiré et `module_check` retourne 1

## ADDED Requirements

### Requirement: Connexion guidée par 1Password
Après l'installation du client, la liste de serveurs et le profil AppArmor, le module SHALL lancer le parcours de connexion guidée du socle pour `rocketchat.imarcom.net` : l'identifiant de l'élément 1Password de Rocket.Chat affiché, son mot de passe copié dans le presse-papiers, le client ouvert, la consigne donnée, puis l'attente de la connexion. La connexion SHALL être constatée, sans `sudo`, sans réseau et sans 1Password, dans la configuration du client, par la même sonde dans le parcours et dans `module_check`. Le mot de passe MUST NOT apparaître à l'écran ni dans le journal. Si le parcours n'aboutit pas (pas de session 1Password, mot de passe illisible, « Passer »), le module SHALL déclarer l'étape manuelle de se connecter à Rocket.Chat, MUST NOT échouer, et reste à faire. Un identifiant illisible MUST NOT interrompre le parcours : le module avertit et le parcours continue sans l'afficher.

#### Scenario: Connexion guidée réussie
- **WHEN** une session 1Password est active et que l'utilisateur colle le mot de passe dans le formulaire du client ouvert par le module
- **THEN** la connexion est constatée, le presse-papiers est vidé, aucune étape manuelle n'est déclarée, `module_check` retourne 0, et le mot de passe ne figure ni dans la sortie du script ni dans son journal, alors que l'identifiant y est affiché

#### Scenario: Déjà connecté
- **WHEN** le module s'exécute alors que l'utilisateur est déjà connecté à `rocketchat.imarcom.net`
- **THEN** aucune lecture dans 1Password n'a lieu et le client n'est pas ouvert

#### Scenario: Sans session 1Password
- **WHEN** aucune session 1Password n'est active
- **THEN** le résumé final demande de se connecter à Rocket.Chat, le module se termine sans erreur et `module_check` retourne 1

#### Scenario: Passer
- **WHEN** le délai d'attente s'écoule et l'utilisateur choisit de passer
- **THEN** le presse-papiers est vidé, le résumé final demande de se connecter à Rocket.Chat, le module se termine sans erreur et `module_check` retourne 1

#### Scenario: Identifiant illisible
- **WHEN** le mot de passe est lisible dans 1Password mais pas l'identifiant
- **THEN** le module avertit, copie le mot de passe, ouvre le client et attend la connexion

#### Scenario: Connecté à un autre serveur seulement
- **WHEN** le client est connecté à un autre serveur que `rocketchat.imarcom.net`
- **THEN** `module_check` retourne 1

## REMOVED Requirements

### Requirement: Connexion déclarée comme étape manuelle
**Reason**: Remplacée par la connexion guidée par 1Password ; l'étape manuelle n'est plus déclarée que si le parcours n'aboutit pas.
**Migration**: Aucune ; sur un poste où l'utilisateur est déjà connecté, `module_check` le constate et rien n'est refait.
