## Context

Voir `proposal.md`. Relevés sur le poste de référence (WSL, 28–29 sept 2026) — sans nom propre aux projets, par règle (spec, première exigence) :

| Sujet | Constat |
|---|---|
| Dépôts | cinq dépôts sous `~/projets/<client>/` (dont deux dans un sous-dossier `legacy/`), tous `git@bitbucket.org:<organisation>/<dépôt>.git` ; branches de travail en cours sur deux d'entre eux ; `node_modules` dans l'un |
| Accès Bitbucket | **corrigé le 29 sept 2026 (VM, tâche 2.2)** : Bitbucket accepte `~/.ssh/id_ed25519` de la WSL (`SHA256:UrvJ…`), un fichier **antérieur** au module `git` (laissé intact par lui), qui n'est **pas** la clé « GitHub SSH Key » de 1Password (`SHA256:ukjG…`, servie par l'agent en VM) : clones refusés en VM (`Permission denied (publickey)`). Le constat d'exploration (« rien à enregistrer chez Bitbucket ») reposait sur une supposition non vérifiée |
| Hôte Bitbucket | `https://bitbucket.org/site/ssh` publie ses clés au format `known_hosts` (`bitbucket.org ssh-rsa …`, `ecdsa-sha2-nistp256 …`, `ssh-ed25519 …`) ; le module `git` ne pose que `github.com` |
| Préparation des projets | le projet principal : `make setup` (`scripts/setup.sh`) — prérequis `node` ≥ 20.9, `pnpm`, `docker` ; facultatifs `mkcert`, `vault`, `jq` ; `.env`, secrets depuis Vault (sans question si `~/.vault-token` existe), `pnpm install`, `docker compose up`, données ; en fin, liste « à faire à la main » : `mkcert -install` et la ligne de son domaine local dans `/etc/hosts` (un second domaine pour Storybook, d'après son `Makefile`) ; le guide : `make setup` = `pnpm install` + crochet git ; la documentation et les dépôts legacy : pas de `make setup` |
| `mkcert` | 1.4.4 et `libnss3-tools` dans les dépôts d'Ubuntu 26.04 ; pas de `~/.pki/nssdb` dans la WSL |
| Accès legacy | `~/.ssh/config` : un bloc `Host` pour l'hôte legacy (nom d'hôte interne, identifiant, `IdentityFile ~/.ssh/id_ed25519_legacy`, `IdentitiesOnly yes`, `ControlMaster`/`ControlPath`/`ControlPersist` — second facteur à la connexion) ; la clé est un fichier du seul poste actuel. Le même fichier porte aussi `Host vm` (propre à la WSL) |
| Runner | un module « déjà fait » est sauté même nommé (`setup.sh projets`), pas d'option `--force` : d'où la commande `--pull-projets` plutôt qu'un `pull` dans le module |
| 1Password | `module_check` de `1password` exige une session ouverte ; sans l'application (WSL), la session ne vit que dans le processus qui l'ouvre. **Agent SSH** (doc « SSH agent config ») : sans `~/.config/1Password/ssh/agent.toml`, il ne sert que les clés des coffres Personal, Private ou Employee — une clé du coffre `Imarcom` ne serait jamais proposée ; `SSH_AUTH_SOCK` n'est exporté que par le fragment `config/1password/commonrc.sh`, donc dans un **nouveau** terminal seulement |
| `run` | ferme l'entrée standard de la commande (`</dev/null`, `lib/core.sh`) : une commande qui lit l'entrée standard par `run`/`run_sudo` ne reçoit rien |

Helpers réutilisés : `ensure_git_clone` (clone ; même origine → rien ; dossier étranger → échec nommé), `ensure_line`, `op_read`, `op_session_active`, `apt_install`, `run`/`run_sudo`, `manual_step`. Modèle : `modules/30-git.sh` (`known_hosts` depuis une source officielle ; clé SSH par l'agent ou en fichier ; critère « agent disponible » = paquet `1password` installé).

## Goals / Non-Goals

**Goals :** un poste neuf retrouve ses dépôts aux mêmes chemins en une commande ; rien de propre aux projets dans le dépôt ; aucun clone existant touché par le module ; mise à jour sûre (jamais de fusion, jamais de perte de travail) ; `module_check` hors ligne.

**Non-Goals :** lancer `make setup` ; installer les prérequis des projets déjà couverts par d'autres modules (`node`, `docker`, `vault`) ; gérer `~/.ssh/config` au-delà d'une ligne d'inclusion ; relever les domaines locaux automatiquement (champ tenu à la main) ; `known_hosts` de l'hôte legacy (accepté à la première connexion).

## Decisions

### D1. Éléments 1Password et format
- `op://Imarcom/Projets` (note sécurisée) : `notesPlain` = **arbre**, une ligne par dépôt `<chemin relatif au HOME><TAB><url>`, triée ; lignes vides et `#…` ignorées ; champ texte **`hosts`** = domaines locaux, tenu par l'utilisateur ; séparateurs acceptés : sauts de ligne, espaces et virgules (un champ texte de l'application peut ne pas être multiligne — tâche 0.1). Constantes `PROJETS_OP_ITEM`, `PROJETS_TREE_REF="$PROJETS_OP_ITEM/notesPlain"`, `PROJETS_HOSTS_REF="$PROJETS_OP_ITEM/hosts"`.
- `op://Private/Legacy SSH` (clé SSH, importée par l'utilisateur ; coffre **`Private`**, comme `GitHub SSH Key` : l'agent de 1Password n'en sert pas d'autre sans `agent.toml` — corrigé le 29 sept 2026, contre-vérification ; écarté : un `agent.toml`, qui, une fois présent, ne sert que les clés qu'il liste et obligerait à y déclarer aussi la clé GitHub) : `private key` (lue avec `?ssh-format=openssh`), `public key`, `notesPlain` = bloc `Host` tel qu'il est dans `~/.ssh/config` aujourd'hui.
- Noms neutres (décision de l'utilisateur, 29 sept 2026) : ils figurent dans le code public.
- Constantes : `PROJETS_LEGACY_ITEM="op://Private/Legacy SSH"`.
- Champ `hosts` absent : `op read` rend 1 et « item 'Imarcom/<élément>' does not have a field '<champ>' » (relevé 0.2) → traité comme vide (même lecture que `_thunderbird_op`, message relevé à la tâche 0.4 de `thunderbird-comptes`).

### D2. Validation de l'arbre (le contenu de 1Password décide où le module écrit)
Chemin : relatif, commence par `projets/` (constante `PROJETS_ROOT_REL="projets"`, racine `PROJETS_ROOT="$HOME/$PROJETS_ROOT_REL"`), sans segment `..`, `.` ni vide, caractères `[A-Za-z0-9._/-]` seulement. URL : `git@<hôte>:<chemin>` ou `ssh://…` ou `https://…` (motif en constante `PROJETS_URL_RE`, surchargeable pour les tests, qui clonent depuis `file://`). Ligne invalide → `log_warn` qui la nomme, ligne sautée (spec : pas d'échec).

### D3. Clonage (module et `--pull-projets`)
**Agent pendant l'exécution** : le fragment de `1password` n'agit que dans un nouveau terminal ; au bootstrap (`base`, `1password`, `git`, `projets` d'une traite), aucune clé n'est sur disque et `SSH_AUTH_SOCK` n'est pas exporté — les clones échoueraient (`Permission denied`). Le module (et `--pull-projets`) exporte donc `SSH_AUTH_SOCK="$OP_AGENT_SOCK"` quand `op_agent_ready` est vrai, avant tout clonage ou `fetch` (contre-vérification, 29 sept 2026).
`_projets_clone <chemin> <url>` : `ensure_git_clone "$url" "$HOME/$chemin"` avec `GIT_SSH_COMMAND="ssh -o BatchMode=yes"` et `GIT_TERMINAL_PROMPT=0` (aucune question : hôte inconnu ou identifiants → échec). Parent créé (`mkdir -p`). Le module parcourt tout l'arbre, garde le premier échec et rend 1 à la fin (spec : tenter les autres). Dépôt **fraîchement cloné** (le dossier n'existait pas) et `Makefile` avec une cible `setup:` (`grep -qE '^setup:' Makefile`, lecture de fichier, pas de tube) → `manual_step "make setup dans ~/<chemin>"`.
Sans session 1Password / élément illisible / arbre vide → `manual_step "$PROJETS_SNAPSHOT_MANUAL"` (« Relever les projets sur le poste de référence : setup.sh --snapshot-projets, puis relancer »), retour 0.

### D4. `known_hosts` de Bitbucket
Comme `_git_known_hosts` : `curl -fsSL https://bitbucket.org/site/ssh` (lignes déjà au format `bitbucket.org <type> <clé>`), chaque ligne par `ensure_line` dans `~/.ssh/known_hosts` (0600) ; contrôle `ssh-keygen -F bitbucket.org`. Réponse vide ou lignes qui ne commencent pas par `bitbucket.org ` → échec nommé.

### D5. `mkcert`
`apt_install mkcert libnss3-tools` dans `module_install`. Dans `module_configure` : `mkcert -install` (par `run`) seulement si l'autorité manque — constat `[[ -f "$(mkcert -CAROOT)/rootCA.pem" ]]` **et** certificat de l'autorité dans le magasin du système (`/usr/local/share/ca-certificates/mkcert_development_CA_*.crt`, chemin relevé à la tâche 0.3). `mkcert -install` appelle `sudo` lui-même : le ticket du runner (`sudo_keepalive`) suffit. Bases NSS des navigateurs : `mkcert` les met à jour s'il les trouve. **Relevé en VM (tâche 0.3, 29 sept 2026)** : après `navigateur` (Brave lancé pour Brave Sync, Firefox jamais lancé), **aucune base NSS n'existe** (`~/.pki/nssdb` absent, aucun profil Firefox) : `mkcert -install` → « The local CA is now installed in the system trust store! » puis « ERROR: no Firefox and/or Chrome/Chromium security databases found » (code 0). Autorité dans `/usr/local/share/ca-certificates/mkcert_development_CA_<n>.crt` seulement. Confiance des navigateurs : **hors de ce change**, à régler dans un change à part (décision de l'utilisateur, 29 sept 2026).

### D6. `/etc/hosts`
Domaine validé (`^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$`). Présent si une ligne active (hors `#`) le porte comme nom (champ 2 et suivants), quelle que soit l'adresse (`awk`, lecture seule). Ajout : `run_sudo sh -c 'printf "127.0.0.1\t%s\n" "$1" >>"$2"' _ "$domaine" "$PROJETS_HOSTS_FILE"` — le domaine passe en argument, jamais interprété par le shell ; pas de `… | run_sudo tee -a` : `run` ferme l'entrée standard, `tee` ne recevrait rien (contre-vérification, 29 sept 2026). Jamais de réécriture du fichier. Constante `PROJETS_HOSTS_FILE` surchargeable (tests). Dans `--pull-projets`, `sudo -v` n'est demandé que si un domaine manque (spec du runner : `sudo` seulement si nécessaire).

### D7. Accès legacy
Constantes `PROJETS_LEGACY_ITEM` (D1), `PROJETS_LEGACY_KEY="$HOME/.ssh/id_ed25519_legacy"`, `PROJETS_SSH_CONF_DIR="$HOME/.ssh/config.d"`, `PROJETS_SSH_CONF="$PROJETS_SSH_CONF_DIR/projets.conf"`, `PROJETS_SSH_INCLUDE="Include config.d/*.conf"`.
1. Clé publique : lue et écrite (0644) si absente ou différente.
2. Clé privée : seulement si l'agent n'est pas disponible (même critère que `git` : paquet `1password` installé) et qu'elle est absente ; `umask 077`, jamais par `run` ni `$(…)` affiché ; existante → laissée intacte (comme `git`).
3. Bloc : `notesPlain` écrit dans `projets.conf` (0600, dossier 0700) s'il diffère ; contenu vide → étape manuelle.
4. Inclusion : `~/.ssh/config` créé en 0600 s'il manque ; la ligne `PROJETS_SSH_INCLUDE` absente → **insérée en tête** (fichier temporaire du même dossier, même mode, `mv`) — `ensure_line` ajoute en fin, or une directive placée après un bloc `Host` ne vaut que pour cet hôte (`ssh_config(5)`).
5. `IdentityFile` avec l'agent (clé du coffre `Private`, D1) : le bloc garde `IdentityFile ~/.ssh/id_ed25519_legacy` ; avec `IdentitiesOnly yes` et la clé privée absente, `ssh` lit `id_ed25519_legacy.pub` et demande à l'agent la clé correspondante — **confirmé en VM (tâche 0.3, 29 sept 2026)** : `ssh -v` vers l'hôte legacy → « get_agent_identities: agent returned 2 keys », « Will attempt key: ~/.ssh/id_ed25519_legacy … explicit agent », « Offering public key … », « Server accepts key » ; la signature attend ensuite l'autorisation de l'application. Le bloc reste donc tel quel.
Élément absent ou champ illisible → `manual_step "$PROJETS_LEGACY_MANUAL"` (« Importer la clé SSH legacy dans 1Password (coffre Private, élément Legacy SSH, bloc Host en note) »), retour 0.

### D8. Relevé (`projets_snapshot`)
`find "$PROJETS_ROOT" -name node_modules -prune -o -type d -name .git -print` → parents, triés (`LC_ALL=C sort`), puis **filtre des dépôts imbriqués** : un chemin dont un chemin retenu avant lui est préfixe (`<retenu>/`) est écarté — `-prune` sur `.git` n'élague que `.git`, pas ses frères (contre-vérification, 29 sept 2026 ; spec : « sans descendre dans un dépôt »). `origin` par `git -C … remote get-url origin` ; absent → avertissement. Arbre trié (`LC_ALL=C sort`). Contenu actuel lu (`op read`) : identique → « arbre inchangé », rien d'écrit. Écriture : élément absent → `op item create --category "Secure Note" --vault Imarcom --title Projets …`, présent → `op item edit` sur `notesPlain` seul ; forme relevée à la tâche 0.2 (WSL, op 2.39.0, 29 sept 2026) : `op item create --category "Secure Note" --title Projets --vault Imarcom "notesPlain=$arbre"` et `op item edit Projets --vault Imarcom "notesPlain=$arbre"` conservent tabulations et sauts de ligne octet pour octet (relu par `op read`), et l'édition de `notesPlain` laisse le champ `hosts` intact. L'arbre passe en argument (visible dans `ps` le temps de l'appel) : il n'est pas un secret. L'arbre n'est pas un secret, mais il reste hors du journal (seuls le nombre et les chemins sont affichés).

### D9. Mise à jour (`projets_pull`)
Arbre relu (D1, D2) ; domaines (D6) ; puis pour chaque ligne :
- absent → `_projets_clone`, compté « cloné » ;
- dossier étranger → compté en échec (comme D3) ;
- sinon `git -C … fetch --prune --quiet` (mêmes variables que D3 ; échec → compté en échec) ; `git status --porcelain --untracked-files=no` non vide → « modifications en cours » (un fichier non suivi n'empêche pas l'avance ; s'il devait être écrasé, `git merge --ff-only` refuse de lui-même et le dépôt est compté en échec, intact) ; pas de branche suivie (`@{u}`) ou tête détachée → « sans branche suivie » ; `git rev-list --left-right --count HEAD...@{u}` : `0 0` → à jour ; `0 n` → `git merge --ff-only @{u}` → « mis à jour » ; `m n` avec `m > 0` → « en avance » (m, 0) ou « divergé » (m, n), laissé.
Bilan final (compteurs + liste des laissés de côté avec leur raison) ; retour 1 si un clonage ou une récupération a échoué.

### D10. Runner
`setup.sh` : `--snapshot-projets` et `--pull-projets` dans `main` et `usage`. `discover_modules` ; module `projets` absent → `die`. `module_state 1password` ≠ `fait` → `run_modules 1password` (même processus, **sans** `sudo_keepalive`). Cas usuel, la session seule manque (WSL) : ses helpers apt et de politique ne touchent à rien quand tout est en place, aucun `sudo`. Installation à faire : `run_sudo` (`sudo -n`) échoue sans ticket → le runner s'arrête, code non nul, en invitant à lancer `setup.sh 1password` (contre-vérification, 29 sept 2026). `sudo` des commandes : `sudo -v` (interactif) juste avant la première écriture système (`/etc/hosts`), jamais au démarrage — spec du runner, exigence « élévation unique » modifiée. Puis `module_call "${MOD_FILE[projets]}" projets_snapshot` ou `projets_pull` ; code de retour propagé ; ni menu ni résumé des modules.
Alternative écartée : un mécanisme générique de « commandes de module » (`MODULE_COMMANDS`) — un seul module en a besoin aujourd'hui.

### D11. `module_check`, sans copie locale de l'arbre (décision de l'utilisateur, 29 sept 2026)
Au moins un dépôt : `[[ -n $(find "$PROJETS_ROOT" -maxdepth 6 -name node_modules -prune -o -type d -name .git -print -quit 2>/dev/null) ]]` (élagage de `node_modules` : ce constat tourne à chaque affichage du menu) ; `ssh-keygen -F bitbucket.org` ; `pkg_installed mkcert libnss3-tools` ; autorité (D5) ; accès legacy (D7 : `.pub`, clé privée si pas d'agent, `projets.conf` non vide, ligne d'inclusion). Écarté (utilisateur) : copie locale de l'arbre, qui ferait dépendre le constat d'un fichier d'état (règle de `CLAUDE.md`).

### D12. Métadonnées
`modules/80-projets.sh` : `MODULE_NAME="projets"`, `MODULE_DESC="dépôts de travail depuis 1Password ; mkcert ; domaines locaux ; accès SSH legacy"` (une ligne, sans `|`), `MODULE_GROUP="projets"`, `MODULE_DEPS="base 1password git"`, pas de `MODULE_NEEDS_GUI`. `node`, `docker`, `vault` ne sont pas des dépendances (ils servent à `make setup`, pas au module) ; ils passent avant dans l'ordre des fichiers quand on lance tout.

### D13. Tests (`tests/test-projets.sh`, `tests/test-run.sh`)
`git` **réel** avec des dépôts nus locaux comme dépôts distants (`file://`, `PROJETS_URL_RE` élargi dans le test) — la logique d'avance rapide se vérifie mieux sur de vrais dépôts ; `HOME` du test ; doublures : `op` (session, lectures par référence, `item get/create/edit` tracés, contenu écrit gardé dans un fichier), `curl` (clés de Bitbucket), `mkcert` (`-CAROOT` vers un dossier du test, `-install` tracé), `dpkg-query`, et **`sudo` factice** en tête du `PATH` (exécute la commande reçue sans élévation, accepte `-v`/`-n`) — `run_sudo` et `run` restent **les vrais**, pour que le `</dev/null` de `run` s'applique en test comme en vrai (une doublure de `run_sudo` masquerait le bogue de `tee`, contre-vérification) ; `PROJETS_HOSTS_FILE` du test.
Cas : arbre → clones et étapes `make setup` (seulement les frais, seulement avec cible `setup:`) ; clone existant intact (fichier modifié gardé) ; dossier étranger → échec nommé, autres clonés ; lignes invalides (`..`, absolu, hors `projets/`, URL invalide) sautées ; sans session / arbre vide → étape, retour 0 ; `known_hosts` sans doublon ; `mkcert -install` seulement sans autorité ; `/etc/hosts` : ajout, déjà présent (autre adresse), commenté ignoré, domaine invalide refusé, champ absent ; legacy : avec agent (pas de clé privée), sans agent (0600, absente de la sortie et du journal), `Include` inséré avant le premier `Host` et une seule fois, élément absent → étape ; relevé : arbre trié, dépôt sans `origin` signalé, **dépôt imbriqué dans un dépôt écarté**, `node_modules` non parcouru, inchangé → aucune écriture, élément absent → création ; mise à jour : en retard → avancé (y compris avec un fichier non suivi), modifications suivies en cours / sans suivi / divergé / en avance → intacts et nommés, `SSH_AUTH_SOCK` exporté quand l'agent est prêt, nouveau dépôt cloné, code non nul sur échec ; `module_check` : chacune de ses conditions. `test-run.sh` : aide, option sans module `projets` (fixtures) → erreur qui le nomme.

## Risks / Trade-offs

- [Un dépôt manquant ne rend pas le module « à faire »] → accepté (D11) : un clonage en échec fait échouer le module, et `--pull-projets` clone ce qui manque en le disant.
- [Domaines locaux hors de `module_check`] → le module les pose à chaque exécution, `--pull-projets` aussi ; un domaine ajouté plus tard arrive par `--pull-projets`.
- [Arbre modifiable dans 1Password = chemins d'écriture] → validation stricte (D2) : sous `~/projets`, sans `..`, caractères limités ; aucune commande n'est tirée du contenu.
- [`mkcert` et les navigateurs] → la base NSS d'un navigateur installé plus tard n'aura pas l'autorité ; relevé en VM (tâche 0.3) ; au besoin, `mkcert -install` se relance à la main.
- [`IdentityFile` et l'agent] → hypothèse vérifiée en VM (D7.5) avant d'être gravée.
- [Écriture dans 1Password] → première du dépôt ; limitée au champ `notesPlain` d'un élément dédié, jamais sans changement réel.
- [WSL : `/etc/hosts` régénéré par WSL à chaque démarrage (en-tête du fichier ; `generateHosts` non désactivé dans `/etc/wsl.conf`, relevé le 29 sept 2026)] → les domaines ajoutés disparaissent au redémarrage de la WSL ; `--pull-projets` les remet. Sans objet sur le laptop (Ubuntu natif).
- [Réseau de l'entreprise] → l'hôte legacy n'est joignable que depuis le réseau de l'entreprise ou le VPN (point ouvert DNS de la vague 5) : le module ne s'y connecte pas.

## Migration Plan

Poste de référence (WSL) : l'utilisateur crée les deux éléments (tâche 0.1), lance `--snapshot-projets`, puis le module : clones existants reconnus (même origine), `known_hosts`, `mkcert`, `/etc/hosts`, accès legacy — la clé privée existante est laissée intacte et le bloc `Host` actuel de `~/.ssh/config` fait doublon avec `projets.conf` : l'utilisateur retire son ancien bloc à la main (étape de la tâche 2.1). Retour arrière : `git revert` ; les écritures sont additives.

