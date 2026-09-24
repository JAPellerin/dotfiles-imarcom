## Purpose

Installer le client de bureau Rocket.Chat depuis son paquet `.deb` officiel le plus récent, déjà configuré pour le serveur de l'entreprise, afin que l'utilisateur n'ait plus qu'à se connecter.

## ADDED Requirements

### Requirement: Client Rocket.Chat depuis son .deb officiel le plus récent
Le module `rocketchat` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer le paquet `rocketchat` à partir du `.deb` amd64 publié par l'éditeur dans ses releases GitHub, en retenant la plus récente des releases publiées qui en contient un, par les helpers du socle. Un paquet déjà installé MUST NOT être retéléchargé ni réinstallé. L'échec de la recherche ou du téléchargement MUST faire échouer le module en le nommant.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans client Rocket.Chat
- **THEN** le paquet `rocketchat` est installé et son lanceur est présent dans le menu des applications

#### Scenario: Déjà installé
- **WHEN** le paquet `rocketchat` est installé et le serveur pré-configuré
- **THEN** `module_check` retourne 0 et rien n'est téléchargé

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Serveur de l'entreprise pré-configuré
Le module SHALL déployer la liste de serveurs par défaut versionnée dans le dépôt, qui désigne `https://rocketchat.imarcom.net`, dans le dossier des ressources du paquet, emplacement que documente Rocket.Chat pour Linux et que le client relit sans jamais supprimer le fichier, par le helper de fichiers système du socle. Au premier lancement du client, le serveur de l'entreprise SHALL être proposé sans que l'utilisateur ait à saisir son adresse. Le module MUST NOT empêcher l'utilisateur d'ajouter d'autres serveurs. `module_check` SHALL constater que le fichier déployé est identique à celui du dépôt.

#### Scenario: Premier lancement
- **WHEN** l'utilisateur ouvre le client après le module, sur un poste où aucun serveur n'a encore été ajouté
- **THEN** le client s'ouvre sur la page de connexion de `rocketchat.imarcom.net`

#### Scenario: Après le premier lancement
- **WHEN** le client a été ouvert une fois après le module
- **THEN** `module_check` retourne toujours 0

#### Scenario: Fichier différent
- **WHEN** un fichier de serveurs au contenu différent existe à cet emplacement
- **THEN** `module_check` retourne 1 et le module le remplace par la version du dépôt

#### Scenario: Fichier retiré
- **WHEN** la liste de serveurs a été supprimée
- **THEN** `module_check` retourne 1 et le module la réécrit

### Requirement: Profil AppArmor qui permet au client de démarrer
Le module SHALL déployer le profil AppArmor versionné dans le dépôt, qui autorise les espaces de noms utilisateur au binaire du client, dans `/etc/apparmor.d/`, par le helper de fichiers système du socle, et SHALL le charger dans le noyau lorsqu'il vient de l'écrire. Une relance sans changement MUST NOT recharger le profil. Si le chargement échoue, le module MUST échouer et le profil MUST NOT être laissé en place. `module_check` SHALL constater que le profil déployé est identique à celui du dépôt.

#### Scenario: Premier lancement sous Ubuntu 26.04
- **WHEN** l'utilisateur ouvre le client après le module, sur un système qui restreint les espaces de noms utilisateur non privilégiés
- **THEN** le client démarre sans plantage

#### Scenario: Profil retiré ou différent
- **WHEN** le profil a été supprimé ou modifié
- **THEN** `module_check` retourne 1 et le module réécrit puis recharge la version du dépôt

#### Scenario: Chargement en échec
- **WHEN** le chargement du profil échoue
- **THEN** le module échoue, le profil est retiré et `module_check` retourne 1

### Requirement: Connexion déclarée comme étape manuelle
Lorsque le module vient d'installer le client, il SHALL déclarer l'étape manuelle de se connecter à Rocket.Chat. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Première installation
- **WHEN** le module installe le client
- **THEN** le résumé final demande de se connecter à Rocket.Chat
