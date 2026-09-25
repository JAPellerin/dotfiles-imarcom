## Context

Voir `proposal.md`. État actuel (`modules/61-rocketchat.sh`, archivé le 24 sept 2026) : `module_check` = paquet `rocketchat` + `servers.json` + profil AppArmor identiques au dépôt ; `module_install` déclare `ROCKETCHAT_LOGIN_MANUAL` après une installation fraîche ; `module_configure` déploie `servers.json` et le profil AppArmor.

Le socle fournit `guided_login` et `open_detached` (`lib/connexion.sh`, `openspec/specs/module-contract/spec.md`, exigence « Connexion guidée par 1Password ») et la convention D5 de `openspec/changes/archive/2026-09-24-socle-connexion/design.md` : la sonde de connexion entre dans `module_check`, le parcours est lancé dans `module_configure`.

Relevés :

| Source | Constat |
|---|---|
| Client Windows de l'utilisateur (24 sept 2026) | `AppData/Roaming/Rocket.Chat/config.json` : `servers[]` avec `url` et `userLoggedIn: true` une fois connecté |
| Design de `socle-connexion`, Context | signe de connexion retenu pour Linux : `~/.config/Rocket.Chat/config.json`, `servers[].userLoggedIn == true` — **à vérifier en VM** (emplacement et moment d'écriture) |
| 1Password | élément `Imarcom/RocketChat`, type Login (champs `username`, `password`), formulaire du serveur ; pas d'OAuth sur le serveur |
| Paquet `rocketchat` (VM, 25 sept 2026) | **aucune commande dans le `PATH`** (`/usr/bin/rocketchat*` absent) ; lanceur `Exec=/opt/Rocket.Chat/rocketchat-desktop %U`, qui démarre `rocketchat-desktop.bin --disable-gpu --ozone-platform=x11` |
| `~/.config/Rocket.Chat/config.json` (VM, 25 sept 2026, 4.17.2) | **écrit pendant que le client tourne**, à la connexion (10:38:22, client lancé à 10:37) ; `servers: [{"url": "https://rocketchat.imarcom.net/", "userLoggedIn": true, "title": "Imarcom"}]` — URL **avec** `/` final ; D1 confirmé |

## Goals / Non-Goals

**Goals :** la connexion à `rocketchat.imarcom.net` faite par l'utilisateur en collant un mot de passe qu'il n'a pas eu à chercher ; « connecté » constaté sans `sudo`, réseau ni 1Password.

**Non-Goals :** écrire dans la configuration du client (jetons, réglages) ; reprendre la configuration Windows ; une sonde qui interroge le serveur.

## Decisions

### D1. Sonde `_rocketchat_logged_in`
Vraie si `~/.config/Rocket.Chat/config.json` existe et que `jq` y trouve un serveur dont l'URL, sans `/` final, vaut `https://rocketchat.imarcom.net` **et** `userLoggedIn == true` (`jq -e`). Fichier absent, JSON illisible ou `jq` en échec → faux. Chemin surchargeable par `ROCKETCHAT_CONFIG` (tests). Connecté à un autre serveur seulement → faux (spec). L'URL attendue est tirée de `config/rocketchat/servers.json` (une seule source), pas recopiée en constante.
Alternative écartée : interroger l'API du serveur (`/api/v1/me`) — réseau et jeton, contraires à la sonde du socle.
Vérifié en VM le 25 sept 2026 : le fichier est écrit pendant que le client tourne, dès la connexion ; l'URL y porte un `/` final, d'où la comparaison sans `/` final des deux côtés.

### D2. Parcours dans `module_configure`
Après `servers.json` et le profil AppArmor (le client doit pouvoir démarrer et proposer le serveur) :
```
guided_login "Rocket.Chat" _rocketchat_logged_in "$ROCKETCHAT_LOGIN_MANUAL" \
  --user "$ROCKETCHAT_USER_REF" --secret "$ROCKETCHAT_PASSWORD_REF" \
  --open open_detached "$ROCKETCHAT_BIN" ";" \
  -- "Dans Rocket.Chat (rocketchat.imarcom.net) : saisir l'identifiant affiché ci-dessus." \
     "Mot de passe : coller (Ctrl-V), puis « Se connecter »."
```
Constantes en tête de fichier : `ROCKETCHAT_USER_REF="op://Imarcom/RocketChat/username"`, `ROCKETCHAT_PASSWORD_REF="op://Imarcom/RocketChat/password"` (convention `op://` : coffre `Imarcom` nommé). Commande d'ouverture : `ROCKETCHAT_BIN="/opt/Rocket.Chat/rocketchat-desktop"`, celle du lanceur du paquet (aucune commande dans le `PATH`, relevé en VM le 25 sept 2026) : `--open open_detached "$ROCKETCHAT_BIN" ";"`. Aujourd'hui, `module_configure` se termine par un `return 0` anticipé quand le profil AppArmor est déjà à jour : ce retour est restructuré pour que le parcours s'exécute dans tous les cas.

### D3. Étape manuelle
`module_install` ne déclare plus `ROCKETCHAT_LOGIN_MANUAL` : c'est `guided_login` qui la déclare, seulement si le parcours n'aboutit pas. Libellé inchangé.

### D4. Tests (`tests/test-rocketchat.sh`)
`guided_login` réel (pas de doublure) avec les doublures du socle déjà employées par `test-connexion.sh` / `test-navigateur.sh` : `op` (session et lecture ; échec sur demande), `wl-copy` (presse-papiers dans un fichier), `has_gui` vrai, `CONNEXION_WAIT_SECONDS=1`, `CONNEXION_WAIT_INTERVAL=0.1`, `ui_choose` scripté, `setsid` / commande d'ouverture journalisées. Cas : sonde (serveur de l'entreprise connecté → vrai ; `userLoggedIn: false`, autre serveur, URL avec `/` final, fichier absent, JSON invalide) ; `module_check` : installé + fichiers + connecté → 0, pas connecté → 1 ; `module_configure` connecté pendant l'attente (fichier écrit en arrière-plan) → aucune étape, presse-papiers vide, mot de passe absent de la sortie et du journal, identifiant présent ; déjà connecté → aucun `op`, aucune ouverture ; sans session → étape déclarée, retour 0 ; « Passer » → étape, retour 0 ; installation fraîche → plus d'étape déclarée par `module_install`. Cas existants adaptés (`module_check` à 0 exige désormais la connexion).

## Risks / Trade-offs

- [Structure de `config.json` changée par une version du client] → la sonde rend faux même connecté : le module reste « à faire » et chaque relance rouvre le parcours ; visible tout de suite, la sonde se corrige alors. Risque accepté.
- [2FA activée sur le serveur] → l'utilisateur la saisit dans le client pendant l'attente (2 min, puis « Continuer d'attendre »).

## Migration Plan

Poste déjà connecté : `module_check` le constate, rien n'est refait. Retour arrière : revenir au commit précédent.
