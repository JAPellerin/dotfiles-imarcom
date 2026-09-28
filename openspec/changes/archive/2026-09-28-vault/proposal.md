## Why

Le projet client lit ses secrets dans le Vault d'Imarcom (`make env-vault`, lancé aussi par `make setup`) : sans CLI Vault ni jeton, le futur module `projets` ne peut pas préparer son `.env` sans poser de question. Aujourd'hui, la CLI vient de l'ancien `~/vault-sudo.sh` (hors dépôt), l'adresse du serveur est écrite en dur dans `config/shell/commonrc` — alors qu'un module n'édite jamais ce fichier — et la connexion LDAP se fait à la main. Première partie de la vague 5 (décision de l'utilisateur, 28 sept 2026 : `vault` d'abord, puis `projets`, `gnome` plus tard).

## What Changes

- Nouveau module **`vault`** (43, groupe `dev`, non graphique : il s'exécute aussi dans la WSL) : CLI Vault depuis le **dépôt apt officiel de HashiCorp**, déclaré en deb822 par le helper du socle.
- Un ancien fichier de dépôt au format `.list` qui désigne le dépôt de HashiCorp — celui que fait écrire la documentation de HashiCorp, et que l'ancien script a laissé dans la WSL — est **retiré avec son ancienne clé** avant la déclaration du socle : les deux ensemble, avec deux clés différentes, font échouer `apt update` pour tout le poste (décision de l'utilisateur, 28 sept 2026).
- **`VAULT_ADDR=https://vault.imarcom.net`** quitte `config/shell/commonrc` pour le fragment `config/vault/commonrc.sh`, lié en `~/.commonrc.d/vault.sh` : la variable n'existe que si le module est installé.
- **Connexion LDAP scriptée**, sans question : identifiant et mot de passe lus dans l'élément 1Password **`op://Imarcom/Vault`** (distinct de celui du VPN ; aucune approbation sur le téléphone — confirmé par l'utilisateur), jeton enregistré dans `~/.vault-token` comme le fait `vault login`. Mot de passe et jeton ne sont jamais affichés ni journalisés.
- **« Déjà fait » inclut la connexion** : jeton présent et âgé de moins de 30 jours (le jeton LDAP est émis pour 32 jours). Le menu recoche donc `vault` environ une fois par mois ; `Entrée` reconnecte sans question (décision de l'utilisateur, 28 sept 2026).
- Vault injoignable (hors du réseau de l'entreprise, VPN inactif), pas de session 1Password, élément illisible ou connexion refusée : étape manuelle « se connecter à Vault », le module ne fait pas échouer l'exécution et reste « à faire ».

Hors périmètre : le module `projets` (clones Bitbucket, `make setup`, `mkcert`, `/etc/hosts`) ; le renouvellement du jeton (`vault token renew`) ; la résolution du point ouvert DNS du VPN (prérequis sur le laptop, vague 5, mais pas pour valider ce module dans la WSL).

## Capabilities

### New Capabilities
- `module-vault` : CLI Vault depuis le dépôt de HashiCorp (et retrait d'un ancien `.list`), adresse du serveur par fragment `commonrc`, connexion LDAP depuis 1Password, état « déjà fait » avec jeton récent.

### Modified Capabilities
- `module-shell` : le scénario « Déploiement » vérifie le chargement de `.commonrc` par `VAULT_ADDR`, qui quitte ce fichier ; il le vérifie désormais par une valeur qui y reste (`NVM_DIR`).

## Impact

- Nouveaux : `modules/43-vault.sh`, `config/vault/commonrc.sh`, `tests/test-vault.sh`.
- Modifiés : `config/shell/commonrc` (bloc « Vault Imarcom » retiré), `tests/test-shell.sh` (variable témoin du chargement), `ROADMAP.md`.
- 1Password : lecture de `op://Imarcom/Vault/username` et `…/password`, seulement quand une connexion est nécessaire ; jamais dans `module_check`.
- Écritures système : `/etc/apt/keyrings/hashicorp.*` et `/etc/apt/sources.list.d/hashicorp.sources` ; retrait éventuel de `/etc/apt/sources.list.d/hashicorp.list` et de `/usr/share/keyrings/hashicorp-archive-keyring.gpg`.
- Réseau : dépôt de HashiCorp ; `vault.imarcom.net` (adresse privée `172.20.5.32`) pour la connexion seulement — joignable depuis le réseau de l'entreprise ou le VPN.
- Validation : dans la WSL (Vault joignable à travers Windows ; ancien `.list` présent) et en VM (installation fraîche).
