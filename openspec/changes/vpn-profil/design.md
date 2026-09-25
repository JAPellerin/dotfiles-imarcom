## Context

Voir `proposal.md`. État actuel (`modules/65-vpn.sh`, archivé le 24 sept 2026) : `module_check` = paquets `openvpn` et `network-manager-openvpn-gnome` + `vpn_profile_present` (une connexion `vpn` dont `vpn.service-type` contient `openvpn`, par `nmcli`, sans `sudo`) ; `module_configure` déclare `VPN_IMPORT_MANUAL` si aucune n'existe.

Relevés :

| Sujet | Constat |
|---|---|
| Profil (24 sept 2026) | `jpellerin.ovpn` : `ca`, `cert`, `key`, `tls-crypt` intégrés, `auth-user-pass`, UDP ; source Windows `Documents/jpellerin.zip` ; joint à `op://Imarcom/VPN` |
| Élément `op://Imarcom/VPN` | identifiant (`username`) et mot de passe **fixe** (`password`) ; fichier joint lisible par `op read op://Imarcom/VPN/jpellerin.ovpn` (référence d'un fichier par son nom) — **à confirmer** (tâche 0.1) |
| `nmcli connection import type openvpn file <f>` | le nom de la connexion est celui du fichier sans extension ; le greffon extrait les blocs intégrés (`<ca>`, `<cert>`, `<key>`, `<tls-crypt>`) dans des fichiers — emplacement **à relever en VM** (attendu : `~/.cert/nm-openvpn/` de l'utilisateur qui importe) |
| Droits | ajout d'une connexion système depuis la session graphique active : autorisé par polkit à l'utilisateur du bureau — **à vérifier en VM** (sinon `run_sudo`) |
| Piège VM | limite de tâches de `user-1000.slice` avec la mémoire dynamique (mémoire du projet) : sans rapport avec ce module, mais le sélecteur de fichiers de l'import manuel en souffrait |

## Goals / Non-Goals

**Goals :** connexion « Imarcom » prête à activer depuis le menu système, sans invite ; aucun secret à l'écran, au journal, ni sur disque hors de NetworkManager ; jamais de connexion à moitié créée.

**Non-Goals :** démarrage automatique, reconnexion, commande `vpn` (reportés) ; modifier une connexion existante ; mot de passe au trousseau GNOME (écarté, D4).

## Decisions

### D1. Quand importer
Dans `module_configure`, seulement si `vpn_profile_present` est faux (constat refait : sous-shell du runner). Ordre : session 1Password (`op_session_active`, sinon `log_warn` + `manual_step "$VPN_IMPORT_MANUAL"`, retour 0) → lecture de l'identifiant et du mot de passe dans des variables (`op_read`, erreurs vers le journal ; illisible → avertissement + étape manuelle, retour 0) → profil (D2) → import (D3). Constantes en tête : `VPN_OP_ITEM="op://Imarcom/VPN"`, `VPN_OVPN_REF="$VPN_OP_ITEM/jpellerin.ovpn"`, `VPN_USER_REF="$VPN_OP_ITEM/username"`, `VPN_PASSWORD_REF="$VPN_OP_ITEM/password"`, `VPN_CONNECTION_NAME="Imarcom"`.

### D2. Profil : fichier temporaire privé
Le profil contient une clé privée : il ne passe **jamais** par une variable affichée ni par `run`. Dossier temporaire créé par `mktemp -d` dans `$XDG_RUNTIME_DIR` (tmpfs propre à l'utilisateur, 0700) — repli sur `mktemp -d` ordinaire s'il manque —, `chmod 700`, **`add_cleanup "rm -rf …"` enregistré avant l'écriture** (retiré aussi sur échec ou Ctrl-C, comme le presse-papiers de `guided_login`). Écrit par `(umask 077; op_read "$VPN_OVPN_REF" >"$dir/$VPN_CONNECTION_NAME.ovpn")` — pas de `$(…)` : la mémoire du projet note qu'un nettoyage enregistré dans un sous-shell de substitution se perd. Le fichier porte le nom de la connexion : l'import la nomme « Imarcom » directement, sans renommage. Fichier vide ou sans ligne `client`/`remote` → avertissement + étape manuelle (profil pas encore joint à l'élément).

### D3. Import et secrets par `nmcli`
1. `run nmcli connection import type openvpn file "$dir/Imarcom.ovpn"` (le chemin seul est tracé) ; l'UUID est relevé dans la sortie de l'import (`Connection 'Imarcom' (<uuid>) successfully added.`), pas par le nom : une connexion « Imarcom » d'un autre type (WireGuard, par exemple) peut déjà exister, et l'import en crée alors une seconde du même nom. Toutes les étapes suivantes désignent la connexion par cet UUID.
2. `run nmcli connection modify uuid <uuid> connection.autoconnect no +vpn.data username=<identifiant> +vpn.data password-flags=0` — l'identifiant n'est pas un secret (tracé comme `guided_login` l'affiche).
3. Mot de passe **jamais en argument** (il serait visible dans `ps` et tracé par `run`) : envoyé par l'entrée standard à l'éditeur de `nmcli`, sortie vers `/dev/null` —
   `printf 'set vpn.secrets password = %s\nsave\nquit\n' "$escaped" | nmcli connection edit uuid <uuid> >/dev/null 2>&1`
   (`printf` est une commande interne : pas de processus qui porte le mot de passe dans ses arguments). `\` et `,` du mot de passe échappés par `\` (séparateurs de `vpn.secrets`). Trace au journal : `nmcli connection edit uuid <uuid> (mot de passe par l'entrée standard)`.
4. Contrôle : `nmcli -g vpn.data connection show uuid <uuid>` contient `username = <identifiant>` et `password-flags = 0`, et `nmcli --show-secrets -g vpn.secrets connection show uuid <uuid>` n'est pas vide (lu dans une variable, jamais affiché).
Tout échec aux étapes 1 à 4 → `nmcli connection delete uuid <uuid>` si l'UUID est connu, `log_error "Création de la connexion VPN « Imarcom » impossible : <étape>"`, retour 1 (spec : aucune connexion incomplète). Les `unset` des variables secrètes suivent la dernière utilisation.
Commandes sans `sudo` (polkit, session active) ; si la tâche 0.2 montre un refus, `run_sudo` pour l'import et la modification, et D3 le consigne (les fichiers extraits iraient alors sous le `HOME` de root, à relever).
Alternative écartée : écrire soi-même le fichier de connexion dans `/etc/NetworkManager/system-connections/` — reproduit ce que fait le greffon (extraction des blocs intégrés) et contourne NetworkManager.

### D4. Mot de passe dans la configuration système (`password-flags=0`)
Décision de l'utilisateur (25 sept 2026). NetworkManager garde le secret dans le fichier de la connexion sous `/etc/NetworkManager/system-connections/` (root, 0600) : connexion sans invite, sans dépendre du trousseau de la session. Écarté : `password-flags=1` + trousseau GNOME (`secret-tool` avec le schéma de NetworkManager), plus fragile à scripter et à vérifier.

### D5. État et étape manuelle
`module_check` inchangé (`vpn_profile_present`) : une connexion OpenVPN existante — importée par le module ou à la main — suffit, et n'est jamais modifiée. `VPN_IMPORT_MANUAL` reste le texte de l'étape de repli. `MODULE_DESC` : « OpenVPN et son greffon NetworkManager ; profil Imarcom depuis 1Password ».

### D6. Tests (`tests/test-vpn.sh`)
Doublure `nmcli` à état (connexions dans un dossier du test : `import` crée une entrée à partir du nom du fichier et imprime `Connection 'Imarcom' (<uuid>) successfully added.`, `modify`/`edit` enregistrent les données, l'`edit` lit son entrée standard, `delete` retire ; échec sur demande à chaque étape) ; doublure `op` (session, lectures, échec sur demande ; profil factice avec une fausse clé repérable, mot de passe factice avec `,` et `\`) ; `XDG_RUNTIME_DIR` du test. Cas : aucune connexion + session → connexion « Imarcom », `autoconnect no`, `username`, `password-flags = 0`, secret enregistré avec l'échappement attendu, `module_check` 0, aucune étape ; **profil et mot de passe absents** de la sortie et du journal, et du tableau des arguments reçus par la doublure ; dossier temporaire retiré (réussite, échec, et interruption au premier plan comme `test-connexion.sh`) ; sans session → étape, aucun `nmcli import`, retour 0 ; profil vide → étape ; échec de l'import, du `modify`, de l'`edit`, du contrôle → échec nommé, connexion retirée ; connexion OpenVPN existante → aucun `op`, aucune modification ; seule une connexion WireGuard → import ; paquets : cas existants.

## Risks / Trade-offs

- [Syntaxe de `vpn.secrets` dans l'éditeur de `nmcli`] → vérifiée en VM avec le vrai mot de passe (tâche 2.1 : connexion établie sans invite) ; échappement couvert par les tests.
- [Clé privée extraite dans `~/.cert/nm-openvpn/`] → c'est le fonctionnement du greffon, fichiers 0600 de l'utilisateur ; relevé en VM et consigné.
- [Le fichier joint change de nom dans 1Password] → lecture en échec : étape manuelle, avertissement qui nomme la référence ; la constante se corrige.
- [Mot de passe du VPN changé] → la connexion existante n'est pas modifiée (spec) : l'utilisateur le change dans les paramètres réseau, ou supprime la connexion et relance le module.

## Migration Plan

Poste où le profil a déjà été importé à la main : `module_check` le constate, rien n'est touché. Retour arrière : `nmcli connection delete id Imarcom`, revenir au commit précédent.
