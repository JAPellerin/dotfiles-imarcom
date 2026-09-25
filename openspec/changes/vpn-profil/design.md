## Context

Voir `proposal.md`. État actuel (`modules/65-vpn.sh`, archivé le 24 sept 2026) : `module_check` = paquets `openvpn` et `network-manager-openvpn-gnome` + `vpn_profile_present` (une connexion `vpn` dont `vpn.service-type` contient `openvpn`, par `nmcli`, sans `sudo`) ; `module_configure` déclare `VPN_IMPORT_MANUAL` si aucune n'existe.

Relevés :

| Sujet | Constat |
|---|---|
| Profil (24 sept 2026) | `jpellerin.ovpn` : `ca`, `cert`, `key`, `tls-crypt` intégrés, `auth-user-pass`, UDP ; source Windows `Documents/jpellerin.zip` ; joint à `op://Imarcom/VPN` |
| Élément `op://Imarcom/VPN` | identifiant (`username`) et mot de passe **fixe** (`password`) — vérifié par l'utilisateur le 25 sept 2026 : **ni `:` ni espace** au début ou à la fin ; fichier joint lisible par `op read op://Imarcom/VPN/jpellerin.ovpn` (référence d'un fichier par son nom) — vérifié (tâche 0.1) |
| `nmcli connection import type openvpn file <f>` (VM, 25 sept 2026, faux profil) | sortie `Connection 'Test-VPN' (<uuid>) successfully added.` (message traduit selon la langue du système : le module ne l'analyse pas, D6) ; nom = fichier sans extension ; `connection-type = password-tls` ; le greffon extrait `<ca>`, `<cert>`, `<key>` dans **`~/.local/share/networkmanagement/certificates/nm-openvpn/<nom>-{ca,cert,key}.pem`** (0600, à l'utilisateur) |
| Droits (VM, 25 sept 2026) | import, `modify` et `edit` **sans sudo et sans fenêtre** depuis le terminal de la session graphique (polkit) ; **par SSH, refusés** (`Insufficient privileges`) et secrets illisibles (`--`) : le module s'exécute dans la session graphique (`MODULE_NEEDS_GUI`), et vérifie l'autorisation avant l'import (D4) |
| Stockage (VM, 25 sept 2026) | Ubuntu 26.04 enregistre la connexion **par netplan** : `/etc/netplan/90-NM-<uuid>.yaml` (root, 0600), rendu en `/run/NetworkManager/system-connections/netplan-NM-<uuid>.nmconnection` ; `/etc/NetworkManager/system-connections/` reste vide ; secret dans `vpn-secrets.password` |
| Éditeur de `nmcli` (VM, 25 sept 2026) | **répète sur sa sortie chaque commande reçue**, mot de passe compris (`nmcli> set vpn.secrets password = …`) ; `set vpn.secrets password = ab\,c\\d` enregistre exactement `ab,c\d` (lu dans le YAML de netplan) : échappement de D6 confirmé |
| Relevé 0.3 (VM, 25 sept 2026, faux profil avec `tls-crypt`, mot de passe factice `ab,c\d`) | **UUID par différence** des listes OpenVPN avant/après l'import : exact. **Permissions** : `settings.modify.system:yes` dans la session graphique, **`:auth`** par SSH (pas `no`) — le contrôle de D4 exige `yes`. **Secret en utilisateur**, session graphique : `nmcli --show-secrets -g vpn.secrets …` → `password = ab\\,c\\d` (octets `a b \ \ , c \ \ d`) ; `-t -f vpn.secrets` → `vpn.secrets:password = ab\,c\d`. Le format de la valeur échappe `,` en `\,` mais **pas** `\` ; `-g` double ensuite chaque `\`. **`.pem`** : `<nom>-ca.pem`, `-cert.pem`, `-key.pem`, **`-tls-crypt.pem`**, tous `600 <utilisateur>`. **`delete`** : retire le YAML de `/etc/netplan/` et le fichier sous `/run/NetworkManager/system-connections/`, mais **laisse les quatre `.pem`** : le `rm -f` de `_vpn_abandon` est indispensable |
| Piège VM | limite de tâches de `user-1000.slice` avec la mémoire dynamique (mémoire du projet) : sans rapport avec ce module, mais le sélecteur de fichiers de l'import manuel en souffrait |

## Goals / Non-Goals

**Goals :** connexion « Imarcom » prête à activer depuis le menu système, sans invite ; aucun secret à l'écran ni au journal ; sur disque, aucun secret hors de la configuration de NetworkManager et des fichiers que son greffon extrait du profil (0600, à l'utilisateur) ; jamais de connexion à moitié créée, même après une interruption.

**Non-Goals :** démarrage automatique, reconnexion, commande `vpn` (reportés) ; modifier une connexion existante ; mot de passe au trousseau GNOME (écarté, D7).

## Decisions

Numérotation : les décisions de ce change suivent celles du change `vpn` (D1 à D3, `openspec/changes/archive/2026-09-24-vpn/design.md`), que citent déjà les commentaires du module ; un « Dn » du module désigne donc sans ambiguïté l'un ou l'autre design, et l'en-tête du module renvoie aux deux.

### D4. Quand importer
Dans `module_configure`, seulement si `vpn_profile_present` est faux (constat refait : sous-shell du runner). Ordre — aux étapes 1 à 4, chaque empêchement donne `log_warn` + `manual_step "$VPN_IMPORT_MANUAL"`, retour 0 ; à l'étape 5, un échec est une erreur nommée (D6) :
1. session 1Password (`op_session_active`) ;
2. autorisation de modifier les connexions système : `nmcli -t -f PERMISSION,VALUE general permissions` porte `org.freedesktop.NetworkManager.settings.modify.system:yes` (sinon : session sans droits polkit, par exemple `ssh -X` où `has_gui` est vrai) ;
3. profil (D5) — lu **avant** l'identifiant et le mot de passe : sans profil joint, le mot de passe n'est jamais lu ;
4. identifiant et mot de passe dans des variables (`op_read`, erreurs vers le journal ; illisible → étape) ;
5. import (D6).

Constantes en tête : `VPN_OP_ITEM="op://Imarcom/VPN"`, `VPN_OVPN_REF="$VPN_OP_ITEM/jpellerin.ovpn"`, `VPN_USER_REF="$VPN_OP_ITEM/username"`, `VPN_PASSWORD_REF="$VPN_OP_ITEM/password"`, `VPN_CONNECTION_NAME="Imarcom"`, `VPN_CERT_DIR="${VPN_CERT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/networkmanagement/certificates/nm-openvpn}"` (surchargeable, tests).

### D5. Profil : fichier temporaire privé
Le profil contient une clé privée : il ne passe **jamais** par une variable affichée ni par `run`. Dossier temporaire créé par `mktemp -d` dans `$XDG_RUNTIME_DIR` (tmpfs propre à l'utilisateur, 0700) — repli sur `mktemp -d` ordinaire s'il manque —, `chmod 700`, **`add_cleanup "rm -rf …"` enregistré avant l'écriture** (retiré aussi sur échec ou Ctrl-C, comme le presse-papiers de `guided_login`). Pas de `$(…)` : la mémoire du projet note qu'un nettoyage enregistré dans un sous-shell de substitution se perd. Écriture :
`if ! (umask 077; op_read "$VPN_OVPN_REF" >"$dir/$VPN_CONNECTION_NAME.ovpn" 2>>"$LOG_FILE"); then` avertissement qui nomme la référence + étape, retour 0.
Les erreurs de `op_read` vont au journal, comme en D4 : affichées en rouge, elles annonceraient un échec là où il n'y a qu'une étape manuelle. `module_configure` s'exécute dans un `if` du runner (`set -e` n'y agit pas) : `mktemp`, `chmod` et l'écriture sont testés explicitement. Le fichier porte le nom de la connexion : l'import la nomme « Imarcom » directement, sans renommage. Fichier vide ou sans ligne `client`/`remote` → avertissement + étape manuelle (profil pas encore joint à l'élément).

### D6. Import et secrets par `nmcli`
1. **UUID par différence, jamais par la sortie de l'import.** `_vpn_openvpn_uuids` liste les UUID des connexions OpenVPN (même parcours que `vpn_profile_present`). Liste relevée avant, puis `run nmcli connection import type openvpn file "$dir/Imarcom.ovpn"` (le chemin seul est tracé), puis liste relevée après : l'UUID est celui qui n'était pas dans la première. Deux raisons : `run` envoie la sortie de l'import au journal, le module ne la voit pas ; et ce message est traduit selon la langue du système, que le script n'impose pas. Pas le nom non plus : une connexion « Imarcom » d'un autre type (WireGuard, par exemple) peut déjà exister, et l'import en crée alors une seconde du même nom. Aucune ou plusieurs nouvelles → échec nommé (D6, fin). Toutes les étapes suivantes désignent la connexion par cet UUID.
2. **Garde contre l'interruption, dès l'UUID connu** : `_VPN_PENDING_UUID=<uuid>` et `add_cleanup _vpn_abandon`. `_vpn_abandon` ne fait rien si `_VPN_PENDING_UUID` est vide ; sinon `nmcli connection delete uuid "$_VPN_PENDING_UUID"` (sortie au journal) et `rm -f "$VPN_CERT_DIR/$VPN_CONNECTION_NAME"-*.pem`. Le nettoyage s'exécute à la sortie du sous-shell de `module_call` (`cleanup_scope`), donc aussi sur Ctrl-C. `_VPN_PENDING_UUID` n'est vidé qu'après le contrôle réussi (étape 6). Le retrait des `.pem` par motif est sûr : le module n'importe que si aucune connexion OpenVPN n'existe, aucun `Imarcom-*.pem` n'appartient donc à une connexion vivante ; le motif couvre aussi `tls-crypt`, présent dans le vrai profil.
3. `run nmcli connection modify uuid <uuid> connection.autoconnect no +vpn.data username=<identifiant échappé> +vpn.data password-flags=0` — l'identifiant n'est pas un secret (tracé comme `guided_login` l'affiche) ; `\` et `,` y sont échappés comme pour le mot de passe (séparateurs de `vpn.data`). **Cette étape précède l'éditeur** : avec `autoconnect` à `yes`, l'éditeur demande une confirmation au `save`, qui casserait l'envoi par l'entrée standard.
4. Mot de passe **jamais en argument** (il serait visible dans `ps` et tracé par `run`) : envoyé par l'entrée standard à l'éditeur de `nmcli`, sortie vers `/dev/null` —
   `printf 'set vpn.secrets password = %s\nsave\nquit\n' "$escaped" | nmcli connection edit uuid <uuid> >/dev/null 2>&1`
   La sortie **MUST** aller vers `/dev/null`, jamais vers le journal ni via `run` : l'éditeur répète la commande reçue, mot de passe en clair (relevé en VM). Son code de sortie ne suffit pas à dire que le `set` a été accepté : l'étape 5 le confirme.
   (`printf` est une commande interne : pas de processus qui porte le mot de passe dans ses arguments). `\` et `,` du mot de passe échappés par `\` (séparateurs de `vpn.secrets`). Trace au journal : `nmcli connection edit uuid <uuid> (mot de passe par l'entrée standard)`.
5. Contrôle, tout lu dans des variables, rien affiché : `nmcli -g vpn.data connection show uuid <uuid>` contient `username = <identifiant>` et `password-flags = 0` ; `nmcli --show-secrets -g vpn.secrets connection show uuid <uuid>` donne `password = <valeur>`, et **la valeur est égale à la forme attendue, calculée à partir du mot de passe lu dans 1Password** : `,` → `\,` (format de la valeur ; `\` n'y est pas échappé), puis chaque `\` doublé et chaque `:` échappé en `\:` (format de `-g`, dont `:` est le séparateur — une adresse MAC y sort `AA\:BB\:…`) — relevé 0.3 : `ab,c\d` → `ab\\,c\\d`. On compare les formes échappées, calculées du côté connu, plutôt que de désechapper la sortie : une seule transformation à écrire et à tester. Une valeur vide, `--` (secret illisible, relevé par SSH) ou différente échoue.
6. Réussite : `_VPN_PENDING_UUID=` (la garde ne supprime plus rien) ; les `unset` des variables secrètes suivent leur dernière utilisation.

Tout échec aux étapes 1 à 5 → `_vpn_abandon` appelé tout de suite (connexion retirée par son UUID s'il est connu, `.pem` retirés), `log_error "Création de la connexion VPN « Imarcom » impossible : <étape>"`, retour 1 (spec : aucune connexion incomplète). Relevé 0.3 : `delete` retire bien le YAML de netplan et le fichier rendu sous `/run`, mais pas les `.pem` — d'où leur `rm -f` explicite.
Commandes sans `sudo` (polkit, session graphique active), vérifié en VM le 25 sept 2026.
Alternative écartée : écrire soi-même la connexion — sous Ubuntu 26.04, un fichier netplan `/etc/netplan/90-NM-<uuid>.yaml` (ailleurs, `/etc/NetworkManager/system-connections/`) — : reproduit ce que fait le greffon (extraction des blocs intégrés) et contourne NetworkManager.

### D7. Mot de passe dans la configuration système (`password-flags=0`)
Décision de l'utilisateur (25 sept 2026). NetworkManager garde le secret dans la configuration système de la connexion — sur Ubuntu 26.04, le fichier netplan `/etc/netplan/90-NM-<uuid>.yaml` (root, 0600, relevé en VM) : connexion sans invite, sans dépendre du trousseau de la session. Écarté : `password-flags=1` + trousseau GNOME (`secret-tool` avec le schéma de NetworkManager), plus fragile à scripter et à vérifier.

### D8. État et étape manuelle
**Dépendance à `1password`** (décision de l'utilisateur, 25 sept 2026) : `MODULE_DEPS="base 1password"`, comme `git` et `navigateur` — `./setup.sh vpn` lancé seul fait d'abord passer `1password` ; delta de spec : exigence « OpenVPN et son greffon… » (dépendances).
`module_check` inchangé (`vpn_profile_present`) : une connexion OpenVPN existante — importée par le module ou à la main — suffit, et n'est jamais modifiée. La garde de D6 empêche qu'une connexion incomplète soit prise pour « déjà fait ». `VPN_IMPORT_MANUAL` reste le texte de l'étape de repli. Commentaires du module devenus faux, réécrits : l'en-tête (« Configuration reportée… », « l'import du profil est une étape manuelle ») et celui de `module_configure` (« Le module ne crée ni ne modifie aucune connexion »). `MODULE_DESC` : « OpenVPN et son greffon NetworkManager ; profil Imarcom depuis 1Password ».

### D9. Tests (`tests/test-vpn.sh`)
Doublure `nmcli` à état (connexions dans un dossier du test, chacune avec son UUID, son type et son `vpn.service-type` : `import` crée une entrée à partir du nom du fichier, dépose des `Imarcom-{ca,cert,key,tls-crypt}.pem` factices dans `VPN_CERT_DIR` et imprime son message de réussite — que le module ignore ; `modify`/`edit` enregistrent les données, l'`edit` lit son entrée standard **et la répète sur sa sortie** (comme le vrai), `delete` retire l'entrée ; `general permissions` répond `yes` ou `no` sur demande ; `--show-secrets -g vpn.secrets` rend la valeur enregistrée au format de `-g` ; échec sur demande à chaque étape, et « `edit` qui réussit sans rien enregistrer ») ; doublure `op` (session, lectures, échec sur demande ; profil factice avec une fausse clé repérable, mot de passe factice avec `,`, `\` et `:`, identifiant factice avec `,`) ; `XDG_RUNTIME_DIR` et `VPN_CERT_DIR` du test ; le fichier charge en plus `lib/op.sh` ; `op` toujours en doublure (le vrai est installé dans la WSL : sans doublure, « sans session » dépendrait de la machine).

Cas :
- aucune connexion + session → connexion « Imarcom », `autoconnect no`, `username` échappé, `password-flags = 0`, secret enregistré avec l'échappement attendu, `module_check` 0, aucune étape ;
- **profil et mot de passe absents** de la sortie et du journal, et du tableau des arguments reçus par la doublure ;
- dossier temporaire retiré : réussite, échec, et interruption au premier plan comme `test-connexion.sh` ;
- **interruption au premier plan après l'import** (doublure `edit` qui attend) → ni connexion, ni `Imarcom-*.pem`, ni dossier temporaire ; `module_check` 1 ;
- sans session → étape, aucun `nmcli import`, retour 0 ;
- autorisation refusée (`general permissions` → `no`) → étape, aucune lecture 1Password, aucun import, retour 0 ;
- profil illisible (pièce jointe absente) → étape, avertissement qui nomme la référence, **mot de passe jamais lu**, aucune erreur rouge à l'écran, retour 0 ; profil vide → étape ;
- échec de l'import, du `modify`, de l'`edit`, du contrôle → échec nommé, connexion retirée, `.pem` retirés ;
- `edit` qui réussit sans enregistrer, ou secret enregistré différent du mot de passe attendu → échec nommé au contrôle, connexion retirée ;
- import qui ne crée aucune connexion OpenVPN nouvelle → échec nommé ;
- connexion WireGuard nommée « Imarcom » déjà présente → import, et toutes les étapes visent la nouvelle connexion (par UUID) ; la WireGuard est intacte ;
- connexion OpenVPN existante → aucun `op`, aucune modification ;
- paquets : cas existants.

Cas existants adaptés : ceux qui attendent l'étape d'import « aucun profil » (lignes 78 à 117 aujourd'hui) passent par la doublure `op` **sans session**, pour rester l'étape de repli ; la doublure `nmcli` existante (`nmcli-refuse`, `nmcli-absent`) est étendue à `import`, `modify`, `edit`, `delete`, `general permissions`.

## Risks / Trade-offs

- [Module `1password` en échec, sauté ou « Abandonner » choisi] → le runner saute aussi ce module, qui en dépend : il n'est **pas même installé** (et non « installé, connexion en étape manuelle »). Voulu (décision de l'utilisateur, 25 sept 2026) : c'est déjà ce qu'annonce `1password` (« les modules qui ont besoin de secrets seront sautés »), comme pour `git` et `navigateur` ; une relance après la connexion à 1Password les reprend. L'étape manuelle « sans session » ne joue que si la session tombe entre `1password` et ce module.
- [Syntaxe de `vpn.secrets` dans l'éditeur de `nmcli`] → vérifiée en VM avec un faux mot de passe contenant `,` et `\` (tâche 0.2) ; le vrai est confirmé à la tâche 2.1 (connexion établie sans invite) ; échappement couvert par les tests, et le contrôle de D6 compare la valeur enregistrée.
- [Éditeur de `nmcli` qui répète le mot de passe] → sortie vers `/dev/null` (D6) ; test : la doublure de `nmcli` répète son entrée standard comme le vrai, et le mot de passe ne doit apparaître ni dans la sortie du module ni dans le journal.
- [Clé privée extraite dans `~/.local/share/networkmanagement/certificates/nm-openvpn/`] → c'est le fonctionnement du greffon, fichiers 0600 de l'utilisateur (relevé en VM), admis par la spec ; retirés par le module sur échec ou interruption (D6), droits constatés à la tâche 2.1.
- [`nmcli connection delete` laisse les `.pem`] → relevé à la tâche 0.3 (le YAML de netplan et le fichier sous `/run` sont bien retirés) : `_vpn_abandon` retire les `.pem` lui-même (D6), le retour arrière aussi.
- [Format de `--show-secrets -g` changé par une version de NetworkManager] → le contrôle échoue et nomme l'étape : la connexion est retirée, rien d'incomplet ne reste ; la forme attendue se corrige (relevé 0.3).
- [Le fichier joint change de nom dans 1Password] → lecture en échec : étape manuelle, avertissement qui nomme la référence ; la constante se corrige.
- [Mot de passe du VPN changé] → la connexion existante n'est pas modifiée (spec) : l'utilisateur le change dans les paramètres réseau, ou supprime la connexion et relance le module.
- [Profil renouvelé par l'équipe TI (nouveau certificat ou clé) et remplacé dans 1Password] → la connexion existante n'est pas mise à jour (spec) : la supprimer (retour arrière ci-dessous), puis relancer le module.

## Migration Plan

Poste où le profil a déjà été importé à la main : `module_check` le constate, rien n'est touché. Retour arrière : repérer l'UUID de la connexion OpenVPN (`nmcli -f NAME,UUID,TYPE connection show`, puis `nmcli -g vpn.service-type connection show uuid <uuid>`), `nmcli connection delete uuid <uuid>`, `rm -f ~/.local/share/networkmanagement/certificates/nm-openvpn/Imarcom-*.pem`, revenir au commit précédent.
