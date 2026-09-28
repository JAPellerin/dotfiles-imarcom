# module-vault Specification

## Purpose

Doter le poste de la CLI Vault de HashiCorp, réglée pour le serveur d'Imarcom, et y connecter l'utilisateur par LDAP avec les identifiants gardés dans 1Password, pour que les projets lisent leurs secrets dans Vault sans poser de question : le module n'est « déjà fait » qu'avec un jeton récent.

## Requirements

### Requirement: CLI Vault depuis le dépôt apt officiel de HashiCorp
Le module `vault` (groupe `dev`, dépend de `base`, de `shell` et de `1password`, sans session graphique requise) SHALL installer le paquet `vault` depuis le dépôt apt officiel de HashiCorp, déclaré au format deb822 avec sa clé dans `/etc/apt/keyrings/` par le helper du socle. Seul un paquet manquant SHALL être passé à apt. Avant de déclarer le dépôt, le module SHALL retirer tout fichier de dépôt au format `.list` qui ne déclare que le dépôt de HashiCorp, ainsi que la clé que la documentation de HashiCorp fait placer dans `/usr/share/keyrings/` lorsqu'aucun fichier de dépôt restant ne la cite, de sorte qu'une seule déclaration de ce dépôt existe et qu'`apt update` réussisse. Un fichier `.list` qui déclare aussi d'autres dépôts MUST NOT être modifié : le module SHALL alors échouer en le nommant. Les autres fichiers de dépôt MUST NOT être modifiés.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Vault
- **THEN** le dépôt de HashiCorp est déclaré une seule fois, le paquet `vault` est installé et `vault version` répond

#### Scenario: Ancien fichier de dépôt présent
- **WHEN** le dépôt de HashiCorp est déjà déclaré dans un fichier `.list` avec une clé dans `/usr/share/keyrings/` (installation selon la documentation de HashiCorp)
- **THEN** ce fichier et cette clé sont retirés, le dépôt est déclaré par le socle, `apt update` réussit, et le paquet `vault` déjà installé n'est pas réinstallé

#### Scenario: Ancien fichier de dépôt mêlé à d'autres dépôts
- **WHEN** un fichier `.list` déclare le dépôt de HashiCorp et un autre dépôt
- **THEN** le module échoue en nommant ce fichier, qui reste intact, et le dépôt n'est pas déclaré une seconde fois

#### Scenario: Lancé seul
- **WHEN** l'utilisateur lance `setup.sh vault` sans autre module
- **THEN** les modules `base`, `shell` et `1password` sont exécutés avant lui

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible (WSL)
- **THEN** le module s'exécute normalement

### Requirement: Adresse du serveur Vault d'Imarcom
Le module SHALL rendre `VAULT_ADDR=https://vault.imarcom.net` disponible dans les shells bash et zsh de l'utilisateur par un fragment de configuration propre au module, chargé par la configuration shell commune seulement si le module est installé. La configuration shell commune MUST NOT définir elle-même cette variable.

#### Scenario: Shells de l'utilisateur
- **WHEN** le module s'est terminé
- **THEN** `bash -ic 'echo $VAULT_ADDR'` comme `zsh -ic 'echo $VAULT_ADDR'` affichent `https://vault.imarcom.net`

#### Scenario: Fragment retiré
- **WHEN** le fragment n'est plus lié dans le dossier des fragments
- **THEN** `module_check` retourne 1 et le module le rétablit

### Requirement: Connexion LDAP depuis 1Password
Lorsque le jeton de l'utilisateur est absent ou âgé de 30 jours ou plus, le module SHALL se connecter au serveur Vault d'Imarcom par la méthode LDAP avec l'identifiant et le mot de passe de l'élément 1Password de Vault, sans poser de question, et SHALL enregistrer le jeton obtenu dans `~/.vault-token`, là où la CLI Vault le lit. Le mot de passe et le jeton MUST NOT apparaître à l'écran, dans le journal ni dans les arguments d'une commande. Un jeton présent et âgé de moins de 30 jours MUST NOT être remplacé, et 1Password MUST NOT être lu dans ce cas. Si le serveur est injoignable, si aucune session 1Password n'est active, si l'élément est illisible ou si le serveur refuse la connexion, le module SHALL avertir en nommant la cause, déclarer l'étape manuelle de se connecter à Vault, MUST NOT échouer, et reste à faire ; un jeton existant MUST NOT être supprimé dans ces cas.

#### Scenario: Connexion réussie
- **WHEN** aucun jeton n'existe, que Vault est joignable et qu'une session 1Password est active
- **THEN** `~/.vault-token` contient un jeton valide, lisible par l'utilisateur seul, `vault token lookup` répond pour l'identifiant de l'élément, aucune étape manuelle n'est déclarée, et ni le mot de passe ni le jeton ne figurent dans la sortie du script ni dans son journal

#### Scenario: Jeton récent
- **WHEN** `~/.vault-token` existe et date de moins de 30 jours
- **THEN** aucune lecture dans 1Password n'a lieu, aucune connexion n'est tentée et le jeton est conservé

#### Scenario: Jeton ancien
- **WHEN** `~/.vault-token` date de 30 jours ou plus, que Vault est joignable et qu'une session 1Password est active
- **THEN** un nouveau jeton remplace l'ancien, sans question

#### Scenario: Vault injoignable
- **WHEN** le serveur Vault ne répond pas (hors du réseau de l'entreprise, VPN inactif)
- **THEN** le module avertit que Vault est injoignable, le résumé final demande de se connecter à Vault, rien n'est lu dans 1Password, le module se termine sans erreur et `module_check` retourne 1

#### Scenario: Sans session 1Password
- **WHEN** Vault est joignable mais qu'aucune session 1Password n'est active
- **THEN** le résumé final demande de se connecter à Vault, le module se termine sans erreur et `module_check` retourne 1

#### Scenario: Connexion refusée
- **WHEN** le serveur refuse l'identifiant ou le mot de passe de l'élément
- **THEN** le module avertit que la connexion a été refusée, le résumé final demande de se connecter à Vault, le module se termine sans erreur, et un jeton existant est conservé

### Requirement: État du module
`module_check` SHALL retourner 0 si et seulement si le paquet `vault` est installé, qu'aucun fichier de dépôt `.list` ne désigne le dépôt de HashiCorp, que le fragment de configuration du module est lié, et que `~/.vault-token` existe, non vide, et date de moins de 30 jours. Le constat MUST NOT nécessiter `sudo`, le réseau ni 1Password.

#### Scenario: Tout est fait
- **WHEN** le paquet est installé, le fragment lié et le jeton récent
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Jeton expiré ou absent
- **WHEN** le paquet est installé et le fragment lié, mais le jeton est absent ou date de 30 jours ou plus
- **THEN** `module_check` retourne 1 et une relance reconnecte sans réinstaller le paquet

#### Scenario: Ancien fichier de dépôt
- **WHEN** un fichier `.list` désigne encore le dépôt de HashiCorp
- **THEN** `module_check` retourne 1
