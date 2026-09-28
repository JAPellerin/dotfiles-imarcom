## Context

Voir `proposal.md`. Relevés dans la WSL (28 sept 2026) :

| Sujet | Constat |
|---|---|
| CLI | Vault v2.1.1, `/usr/bin/vault`, depuis `apt.releases.hashicorp.com`, suite `resolute`, composant `main` |
| Dépôt existant | `/etc/apt/sources.list.d/hashicorp.list` : `deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com resolute main` — forme de la documentation de HashiCorp, écrite par l'ancien `~/vault-sudo.sh` ; clé `/usr/share/keyrings/hashicorp-archive-keyring.gpg` |
| Jeton | `~/.vault-token` (0600) ; `vault token lookup` : `display_name ldap-jpellerin`, politiques `default`, `vault-clients`, `vault-projet`, `vault-dev`, **`creation_ttl` 2 764 800 s (32 jours)**, renouvelable, `explicit_max_ttl` 0 |
| Serveur | `vault.imarcom.net` → `172.20.5.32` (adresse privée ; `rocketchat.imarcom.net` aussi) : joignable depuis la WSL parce que Windows est sur le réseau de l'entreprise ou le VPN ; sur le laptop, il faudra le VPN « Imarcom » (point ouvert DNS, vague 5) |
| Adresse | `export VAULT_ADDR=https://vault.imarcom.net` dans `config/shell/commonrc` (bloc « Vault Imarcom ») ; `tests/test-shell.sh` s'en sert comme variable témoin du chargement de `commonrc` et de la surcharge par un fragment |
| Élément 1Password (tâche 0.1, 28 sept 2026) | `op://Imarcom/Vault` (distinct du VPN ; pas d'approbation sur le téléphone) : champs `username` (STRING, `jpellerin`), `password` (CONCEALED), `notesPlain` |
| `vault status` (tâche 0.2 c, WSL, 28 sept 2026) | joignable → code 0 en 0,4 s ; adresse qui ne répond pas → code 1 (`context deadline exceeded`) au bout de `VAULT_CLIENT_TIMEOUT` (3 → 4,0 s, 5 → 5,1 s) ; nom introuvable → code 1 aussitôt : **`VAULT_STATUS_TIMEOUT` = 5** |
| Connexion (tâche 0.2 a/b, WSL, 28 sept 2026, `HOME` temporaire) | `op read --no-newline …/password \| vault write -field=token auth/ldap/login/jpellerin password=-` → code 0, jeton seul sur la sortie (95 caractères), aucune question ; `printf '%s' "$jeton" \| vault login -no-print -` → code 0, rien sur la sortie, `.vault-token` 0600 ; mauvais mot de passe → code 2, `Code: 400. Errors: * invalid credentials` (sans le mot de passe) ; identifiant vide → code 2, `403 permission denied` sur `auth/ldap/login` ; `op signin` collé dans un bloc de commandes n'ouvre pas la session (à lancer seul) |
| Entrée standard (aide de la CLI 2.1.1) | `vault write` : « If the value is "-", Vault will read the value from stdin » ; `vault login` : « If the argument is "-", the values are read from stdin », `-no-print` : « The token will be still be stored to the configured token helper » |
| Projet client | `scripts/env-from-vault.sh` : `vault token lookup` puis `vault kv get` sur `vault-projet/data/projet-local` ; retombe sur `~/.vault-token` quand `VAULT_TOKEN` est vide ; `make setup` demande un jeton au clavier s'il n'en trouve pas |

Modèles suivis : `modules/22-cli-tools.sh` (fragment `commonrc.sh`, dépendance à `shell`), `modules/65-vpn.sh` (secret par l'entrée standard, jamais en argument ni par `run`, trace au journal écrite à la main), `modules/63-spotify.sh` (dépôt apt, racine `/etc` surchargeable dans les tests).

## Goals / Non-Goals

**Goals :** une seule déclaration du dépôt de HashiCorp, quel que soit l'historique du poste ; `VAULT_ADDR` porté par le module ; jeton obtenu sans question et sans secret visible ; `module_check` hors ligne.

**Non-Goals :** renouveler le jeton ; configurer un assistant de jeton (`token_helper`) ; toucher à `VAULT_TOKEN` ou à un `.env` de projet ; vérifier la validité du jeton auprès du serveur dans `module_check`.

## Decisions

### D1. Dépôt de HashiCorp par le helper du socle
`apt_add_repo hashicorp https://apt.releases.hashicorp.com/gpg https://apt.releases.hashicorp.com auto main` — URL de la clé et du dépôt, suite et composant de la documentation de HashiCorp (« Install Vault », onglet Ubuntu/Debian), en deb822 : `/etc/apt/keyrings/hashicorp.{asc,gpg}` (extension choisie par le helper selon le contenu) et `/etc/apt/sources.list.d/hashicorp.sources`. Puis `apt_install vault` (seul un paquet manquant passe à apt). Constantes `VAULT_KEY_URL`, `VAULT_REPO_URL` en tête du module.
Suite `auto` (nom de code du système) : HashiCorp publie `resolute` (relevé : c'est la suite de la WSL).

### D2. Retrait d'un ancien `.list` (décision de l'utilisateur, 28 sept 2026)
Dans `module_install`, **avant** `apt_add_repo` (qui lance `apt update` : avec les deux déclarations et deux `Signed-By` différents, apt refuse — `Conflicting values set for option Signed-By` —, pour tout le poste) :
1. Fichiers visés : chaque `*.list` de `$APT_SOURCES_DIR` dont une ligne active (hors commentaire) désigne `apt.releases.hashicorp.com`, et aussi `/etc/apt/sources.list` (constante `VAULT_APT_MAIN_LIST`, surchargeable) — ajouté le 28 sept 2026 (remarque de contre-vérification) : ce fichier-là, qui déclare toujours d'autres dépôts, est traité comme un fichier mêlé (étape 2). Lecture par `grep -l`/`grep -E` sur les fichiers eux-mêmes, sans tube vers `grep -q` (piège de `pipefail`).
2. Un fichier dont **toutes** les lignes actives désignent HashiCorp est retiré par `run_sudo rm -f --`. Un fichier qui déclare aussi d'autres dépôts n'est pas touché : échec nommé (« retirer à la main la ligne de HashiCorp de <fichier> ») — le spec interdit de modifier les autres dépôts, et réécrire un fichier mêlé serait deviner.
3. La clé de la documentation, `/usr/share/keyrings/hashicorp-archive-keyring.gpg` (constante `VAULT_LEGACY_KEY`, surchargeable), est retirée si elle existe et qu'aucun fichier restant ne la cite — ni dans `$APT_SOURCES_DIR` (`.list` et `.sources`), ni `/etc/apt/sources.list` (remarque de contre-vérification, 28 sept 2026 ; aucun poste concerné aujourd'hui).
4. `apt_mark_stale` si quelque chose a été retiré.
Le paquet `vault` déjà installé depuis l'ancien dépôt reste installé (même paquet, même origine) : `apt_install` ne le repasse pas à apt.
Alternatives écartées (utilisateur) : garder le `.list` et ne rien écrire (deux formats, `module_check` devant reconnaître les deux) ; échouer en le nommant (ménage à la main).

### D3. `VAULT_ADDR` par fragment
`config/vault/commonrc.sh` (POSIX, en-tête comme `config/cli-tools/commonrc.sh`) : `export VAULT_ADDR=https://vault.imarcom.net`. Lié par `link_config config/vault/commonrc.sh "$SHELL_COMMON_RC_DIR/vault.sh"` dans `module_configure`, constaté par `config_linked` dans `module_check`. D'où la dépendance à `shell` (sans lui, `~/.commonrc` ne charge pas `~/.commonrc.d`), comme `cli-tools`.
Le bloc « Vault Imarcom » quitte `config/shell/commonrc`. `tests/test-shell.sh` s'en servait comme variable témoin (`rc_value`) : il prend `NVM_DIR`, qui reste dans `commonrc` — la surcharge par un fragment se vérifie alors sur une vraie valeur de `commonrc`, ce que le test ne ferait plus avec `VAULT_ADDR`. Spec `module-shell` ajustée de même (scénario « Déploiement »).
Le module n'attend pas le rechargement du shell : il définit lui-même `VAULT_ADDR` (constante `VAULT_ADDR_URL`) pour ses appels à `vault`.
**Avis pour le shell courant** (ajouté le 28 sept 2026, vu en VM à la tâche 2.2) : un terminal ouvert avant le module ne charge pas le fragment ; sans `VAULT_ADDR`, la CLI avertit (`VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200`) puis échoue en `connection refused` — trompeur, la commande existe mais vise le mauvais serveur. Si l'environnement du script n'a pas `VAULT_ADDR` égal à `VAULT_ADDR_URL`, `module_configure` affiche un `log_info` : « VAULT_ADDR : ouvrir un nouveau terminal (ou « source ~/.commonrc.d/vault.sh ») avant d'utiliser vault. » Ni étape manuelle ni effet sur « déjà fait » (décision de l'utilisateur, 28 sept 2026 ; alternative écartée : ne rien dire, comme pour les autres fragments).

### D4. Sonde du jeton, hors ligne (décision de l'utilisateur, 28 sept 2026)
`_vault_token_fresh` : `~/.vault-token` (constante `VAULT_TOKEN_FILE`, surchargeable) existe, **non vide**, et date de moins de `VAULT_TOKEN_MAX_AGE_DAYS` = 30 jours — `find "$VAULT_TOKEN_FILE" -maxdepth 0 -mmin -$((30 * 24 * 60))` dans une substitution, comparée à vide (ni tube ni `grep -q`). 30 et non 32 (`creation_ttl` relevé) : deux jours de marge pour que le jeton ne meure pas entre deux passages.
Un jeton renouvelé à la main (`vault token renew`) garde la date de son fichier : le module se dira « à faire » un peu tôt et reconnectera sans question — sans gravité. Un jeton révoqué côté serveur avant 30 jours passe pour valide : accepté (seul le réseau le verrait, et `module_check` n'y va pas).

### D5. Connexion dans `module_configure`
Après le lien du fragment (D3) :
1. `_vault_token_fresh` → rien (ni `op`, ni réseau).
2. Serveur joignable : `VAULT_ADDR=… VAULT_CLIENT_TIMEOUT=… vault status` (sortie et erreurs au journal). Code 0 → joignable ; 2 (scellé) ou autre → `log_warn` « Vault injoignable (réseau de l'entreprise ou VPN requis) » ou « Vault scellé », étape manuelle, retour 0. Délai court : constante `VAULT_STATUS_TIMEOUT` = 5 s (tâche 0.2 c).
3. `op_session_active`, sinon étape manuelle (« aucune session 1Password »), retour 0.
4. Identifiant et mot de passe par `op_read "$VAULT_USER_REF"` / `"$VAULT_PASSWORD_REF"` dans des variables (erreurs de `op` au journal) ; vide ou illisible → avertissement qui nomme la référence, étape manuelle, retour 0.
5. Jeton : `token=$(printf '%s' "$password" | vault write -field=token "auth/ldap/login/$user" password=- 2>>"$LOG_FILE")` — mot de passe par l'entrée standard (`-` : valeur lue sur stdin, documenté par `vault write`), jamais en argument ; ni `run` (qui tracerait la commande) ni `ui_spin`. Trace écrite à la main au journal : `vault write auth/ldap/login/<identifiant> (mot de passe par l'entrée standard)` — l'identifiant n'est pas un secret. Échec ou jeton vide → `log_warn` « connexion à Vault refusée (voir le journal) », étape manuelle, retour 0 ; le jeton existant n'est pas touché (rien n'a été écrit).
6. Enregistrement : `printf '%s' "$token" | vault login -no-print - >/dev/null 2>>"$LOG_FILE"` — jeton par l'entrée standard ; `vault login` passe par l'assistant de jeton de la CLI, qui écrit `~/.vault-token` en 0600, là où la CLI et le script du projet le relisent. Écarté : écrire `~/.vault-token` soi-même (contournerait un assistant configuré).
7. `unset password token` après la dernière utilisation ; contrôle final `_vault_token_fresh`, sinon échec nommé (« jeton non enregistré ») — seul cas d'échec réel de la connexion.
Aucun `add_cleanup` : rien de temporaire sur disque.
Libellé de l'étape (`VAULT_LOGIN_MANUAL`) : « Se connecter à Vault (réseau de l'entreprise ou VPN actif) : vault login -method=ldap username=<identifiant> ».
Validation préalable (tâche 0.2) : `password=-` lu sur l'entrée standard, `-field=token`, `vault login -no-print -`, codes de `vault status`.

### D6. `module_check`
`pkg_installed vault` ; aucun `.list` actif désignant HashiCorp (même lecture qu'en D2, sans `sudo`) ; `config_linked` du fragment ; `_vault_token_fresh`. Le fichier `.sources` n'est pas constaté (comme pour les autres dépôts du socle : `apt_add_repo` est idempotent).

### D7. Métadonnées et ordre
`modules/43-vault.sh` : `MODULE_NAME="vault"`, `MODULE_GROUP="dev"`, `MODULE_DEPS="base shell 1password"`, pas de `MODULE_NEEDS_GUI`. En-tête : liens vers la doc de HashiCorp suivie, renvoi à la spec principale et à ce design.

### D8. Tests (`tests/test-vault.sh`)
Doublures : `dpkg-query` lu dans un fichier ; `run_sudo` qui journalise et applique `rm -f` dans une racine du test (`APT_SOURCES_DIR` et `VAULT_LEGACY_KEY` sous `$TEST_TMP`) ; `apt_add_repo` et `apt_install` qui comptent ; `op` (session et lectures sur drapeaux, lectures tracées) ; `vault` factice (`status` : code sur drapeau ; `write` : **lit son entrée standard**, trace ses arguments — jamais l'entrée —, rend un jeton factice ou refuse sur drapeau ; `login` : lit le jeton sur l'entrée standard et l'écrit dans `VAULT_TOKEN_FILE` en 0600) ; `VAULT_TOKEN_FILE` et `SHELL_COMMON_RC_DIR` du test ; fonctions appelées par `module_call`.
Cas :
- dépôt : aucun `.list` → rien retiré ; `.list` de la documentation + clé → retirés, `apt_add_repo` appelé ensuite ; `.list` mêlé (HashiCorp + autre) → échec nommé, fichier intact ; autre `.list` sans HashiCorp → intact ; clé encore citée ailleurs → gardée ;
- `module_check` : chacune de ses quatre conditions ; jeton de 29 jours → 0, de 31 jours → 1 (`touch -d`), jeton vide → 1 ;
- connexion : sans jeton + joignable + session → jeton écrit (0600), aucune étape ; **mot de passe et jeton absents de la sortie, du journal et des arguments reçus par `vault`** ; jeton récent → aucun appel à `op` ni à `vault` ; injoignable → étape, aucun `op` ; scellé → étape ; sans session → étape ; champ illisible → étape, avertissement qui nomme la référence ; connexion refusée → étape, **ancien jeton intact** ; jeton ancien → remplacé ;
- métadonnées : `MODULE_DEPS` contient `shell` et `1password` (scénario « Lancé seul ») ;
- `tests/test-shell.sh` : variable témoin `NVM_DIR`.

## Risks / Trade-offs

- [Laptop : Vault seulement par le VPN, dont le DNS ne répond pas dans la VM] → le module ne fait pas échouer l'exécution (étape manuelle) ; point ouvert rattaché à la vague 5 ; la validation de ce module se fait dans la WSL et dans la VM, qui joignent Vault à travers Windows.
- [Jeton renouvelé à la main : fichier ancien, reconnexion un peu tôt] → sans gravité (D4).
- [Jeton révoqué avant 30 jours : « déjà fait » à tort] → accepté ; `make env-vault` le dira (`vault token lookup`), et `setup.sh vault` après suppression de `~/.vault-token` reconnecte.
- [Mot de passe LDAP changé dans l'annuaire sans mise à jour de 1Password] → connexion refusée : étape manuelle nommée, jeton existant gardé.
- [Assistant de jeton configuré ailleurs (`~/.vault` `token_helper`)] → `vault login` le respecte ; la sonde, elle, lit `~/.vault-token` : sur un tel poste le module resterait « à faire ». Aucun poste concerné ; hors périmètre.
- [WSL : `~/.commonrc` est un lien vers le dépôt] → dès que le bloc « Vault Imarcom » quitte `config/shell/commonrc` (tâche 1.1), les nouveaux shells de la WSL perdent `VAULT_ADDR` jusqu'au passage de `setup.sh vault` : enchaîner la tâche 2.1 sans attendre (remarque de contre-vérification, 28 sept 2026).
- [Retrait d'un fichier que le module n'a pas écrit] → seulement un `.list` dont toutes les lignes actives désignent HashiCorp, à l'emplacement des dépôts apt ; un fichier mêlé fait échouer sans rien toucher (D2).

## Migration Plan

WSL de l'utilisateur : premier passage → `hashicorp.list` et l'ancienne clé retirés, `hashicorp.sources` écrit, paquet gardé, fragment lié ; jeton actuel (≈ 18 jours) conservé sans connexion. `VAULT_ADDR` reste défini dans les shells (fragment au lieu de `commonrc`). Retour arrière : `git revert` ; l'ancien `.list` n'est pas recréé (la déclaration deb822 suffit).

