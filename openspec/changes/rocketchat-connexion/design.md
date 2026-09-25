## Context

Voir `proposal.md`. État actuel (`modules/61-rocketchat.sh`, archivé le 24 sept 2026) : `module_check` = paquet `rocketchat` + `servers.json` + profil AppArmor identiques au dépôt ; `module_install` déclare `ROCKETCHAT_LOGIN_MANUAL` après une installation fraîche ; `module_configure` déploie `servers.json` et le profil AppArmor.

Le socle fournit `guided_login` et `open_detached` (`lib/connexion.sh`, `openspec/specs/module-contract/spec.md`, exigence « Connexion guidée par 1Password ») et la convention D5 de `openspec/changes/archive/2026-09-24-socle-connexion/design.md` : la sonde de connexion entre dans `module_check`, le parcours est lancé dans `module_configure`.

Relevés :

| Source | Constat |
|---|---|
| Client Windows de l'utilisateur (24 sept 2026) | `AppData/Roaming/Rocket.Chat/config.json` : `servers[]` avec `url` et `userLoggedIn: true` une fois connecté |
| Design de `socle-connexion`, Context | signe de connexion retenu pour Linux : `~/.config/Rocket.Chat/config.json`, `servers[].userLoggedIn == true` — vérifié en VM le 25 sept 2026 (ligne « `~/.config/Rocket.Chat/config.json` » ci-dessous) |
| 1Password | élément `Imarcom/RocketChat`, type Login (champs `username`, `password`), formulaire du serveur ; pas d'OAuth sur le serveur |
| Paquet `rocketchat` (VM, 25 sept 2026) | **aucune commande dans le `PATH`** (`/usr/bin/rocketchat*` absent) ; lanceur `Exec=/opt/Rocket.Chat/rocketchat-desktop %U`, qui démarre `rocketchat-desktop.bin --disable-gpu --ozone-platform=x11` |
| `~/.config/Rocket.Chat/config.json` (VM, 25 sept 2026, 4.17.2) | **écrit pendant que le client tourne**, à la connexion (10:38:22, client lancé à 10:37) ; `servers: [{"url": "https://rocketchat.imarcom.net/", "userLoggedIn": true, "title": "Imarcom"}]` — URL **avec** `/` final ; D7 confirmé |

## Goals / Non-Goals

**Goals :** la connexion à `rocketchat.imarcom.net` faite par l'utilisateur en collant un mot de passe qu'il n'a pas eu à chercher ; « connecté » constaté sans `sudo`, réseau ni 1Password.

**Non-Goals :** écrire dans la configuration du client (jetons, réglages) ; reprendre la configuration Windows ; une sonde qui interroge le serveur.

## Decisions

Numérotation : les décisions de ce change suivent celles du change `rocketchat` (D1 à D6, `openspec/changes/archive/2026-09-24-rocketchat/design.md`), que citent déjà les commentaires du module ; un « Dn » du module désigne donc sans ambiguïté l'un ou l'autre design, et l'en-tête du module renvoie aux deux.

### D7. Sonde `_rocketchat_logged_in`
Vraie si `$ROCKETCHAT_CONFIG` existe et que `jq -e` y trouve un serveur de l'entreprise connecté :
```
jq -e --arg url "$attendue" \
  'any(.servers[]?; ((.url // "") | rtrimstr("/")) == $url and .userLoggedIn == true)' \
  "$ROCKETCHAT_CONFIG" >/dev/null 2>&1
```
`.servers` absent, `url` nulle, fichier absent ou JSON illisible → faux, sans erreur. L'URL attendue est lue dans `config/rocketchat/servers.json` (une seule source, `jq -r 'first(.[])'`), puis débarrassée de son `/` final ; les deux côtés sont comparés **sans** `/` final : `https://rocketchat.imarcom.net/` (forme relevée en VM) et `https://rocketchat.imarcom.net` donnent vrai. Connecté à un autre serveur seulement → faux (spec).
Chemin : `ROCKETCHAT_CONFIG="${ROCKETCHAT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/Rocket.Chat/config.json}"` — surchargeable (tests) ; le client (Electron) range ses données sous `$XDG_CONFIG_HOME` quand il est défini.
Alternative écartée : interroger l'API du serveur (`/api/v1/me`) — réseau et jeton, contraires à la sonde du socle.
Vérifié en VM le 25 sept 2026 : le fichier est écrit pendant que le client tourne, dès la connexion, et l'URL y porte un `/` final.

### D8. Parcours dans `module_configure`
Après `servers.json` et le profil AppArmor (le client doit pouvoir démarrer et proposer le serveur) :
```
guided_login "Rocket.Chat" _rocketchat_logged_in "$ROCKETCHAT_LOGIN_MANUAL" \
  --user "$ROCKETCHAT_USER_REF" --secret "$ROCKETCHAT_PASSWORD_REF" \
  --open open_detached "$ROCKETCHAT_BIN" ";" \
  -- "Dans Rocket.Chat (rocketchat.imarcom.net) : saisir l'identifiant affiché ci-dessus dans le premier champ du formulaire." \
     "Mot de passe : le coller (Ctrl-V) dans le second champ, puis valider (Entrée)."
```
Consigne **indépendante de la langue** (décision de l'utilisateur, 25 sept 2026) : le client suit la langue du système, que le script n'impose pas ; la consigne désigne les champs par leur place et la validation par la touche Entrée, jamais par un libellé d'interface.
Constantes en tête de fichier : `ROCKETCHAT_USER_REF="op://Imarcom/RocketChat/username"`, `ROCKETCHAT_PASSWORD_REF="op://Imarcom/RocketChat/password"` (convention `op://` : coffre `Imarcom` nommé) ; `ROCKETCHAT_BIN="$ROCKETCHAT_ROOT/opt/Rocket.Chat/rocketchat-desktop"`, la commande du lanceur du paquet (aucune commande dans le `PATH`, relevé en VM le 25 sept 2026), **préfixée par `$ROCKETCHAT_ROOT`** comme `ROCKETCHAT_SERVERS` et `ROCKETCHAT_APPARMOR` : `open_detached` vérifie que la commande existe avant de la lancer (`command -v`), les tests y posent donc un exécutable factice.
Aujourd'hui, `module_configure` se termine par un `return 0` anticipé quand le profil AppArmor est déjà à jour : ce retour est restructuré pour que le parcours s'exécute dans tous les cas.
Lectures dans 1Password (comportement de `guided_login`) : un **mot de passe** illisible → avertissement et étape manuelle ; un **identifiant** illisible → simple avertissement, le parcours continue sans l'afficher.

### D9. Étape manuelle
`module_install` ne déclare plus `ROCKETCHAT_LOGIN_MANUAL` : c'est `guided_login` qui la déclare, seulement si le parcours n'aboutit pas. Libellé inchangé. Commentaires devenus faux, réécrits : celui qui précède `module_install` (« L'étape de connexion est déclarée ici… », renvoi à D3 du change `rocketchat` → installation seule ; connexion dans `module_configure`, D8) et celui de `module_check` (« Déjà fait = paquet installé, liste de serveurs et profil AppArmor… (D4) » → complété : et connecté, constaté par `_rocketchat_logged_in`, D7, sans `op`).

### D10. Tests (`tests/test-rocketchat.sh`)
Le fichier charge en plus `lib/op.sh` et `lib/connexion.sh`. `guided_login` réel (pas de doublure) avec les doublures du socle déjà employées par `test-connexion.sh` / `test-navigateur.sh` : `op` (session et lecture ; échec sur demande), `wl-copy` (presse-papiers dans un fichier), `has_gui` vrai, `CONNEXION_WAIT_SECONDS=1`, `CONNEXION_WAIT_INTERVAL=0.1`, `ui_choose` scripté, doublure `setsid` qui journalise puis exécute la commande reçue ; `ROCKETCHAT_CONFIG="$TEST_TMP/rocketchat/config.json"` **exporté** en tête du fichier, avant tout `module_call` (jamais déduit de `HOME` ni de `XDG_CONFIG_HOME`, que `tests/lib.sh` ne redéfinit pas) ; exécutable factice `$ROCKETCHAT_ROOT/opt/Rocket.Chat/rocketchat-desktop` qui journalise son lancement et, quand le test le demande (fichier drapeau), écrit après un court délai le `config.json` « connecté » — comme le vrai client, pendant qu'il tourne, sans `&` dans le test (pièges du SIGINT ignoré et du processus orphelin).
Nouveaux cas :
- sonde : vrai pour le serveur de l'entreprise connecté, URL avec **et** sans `/` final ; faux pour `userLoggedIn: false`, autre serveur, `.servers` absent, `url` nulle, fichier absent, JSON invalide ;
- `module_check` : installé + fichiers + connecté → 0 ; pas connecté → 1 ;
- `module_configure` : connexion pendant l'attente (fichier écrit par l'exécutable factice) → aucune étape, presse-papiers vide, mot de passe absent de la sortie et du journal, identifiant présent, client lancé ; déjà connecté → aucun `op`, aucun lancement (aucune ligne de `setsid` ni de l'exécutable factice au journal) ; sans session → étape déclarée, retour 0 ; « Passer » → étape, retour 0 ; identifiant illisible → avertissement, parcours poursuivi ;
- installation fraîche → aucune étape déclarée par `module_install` ;
- sonde sur le chemin par défaut : `ROCKETCHAT_CONFIG` non défini et `XDG_CONFIG_HOME` pointé dans le dossier du test → le fichier y est lu.
Cas existants adaptés : un `config.json` « connecté » est posé avant les cas qui appellent `module_configure` sans porter sur la connexion (sinon chacun lancerait le parcours et attendrait) ; les deux assertions « étape de connexion » après `module_install` (lignes 88 et 177 aujourd'hui) sont retirées ou inversées ; `module_check` à 0 exige désormais la connexion ; l'assertion « rien sous ~/.config/Rocket.Chat » (ligne 99 aujourd'hui) devient « aucun `servers.json` sous ~/.config/Rocket.Chat » (le `config.json` du test n'y est plus, mais l'intention — la liste de serveurs n'est déployée que dans `/opt` — reste).

## Risks / Trade-offs

- [Structure de `config.json` changée par une version du client] → la sonde rend faux même connecté : le module reste « à faire » et chaque relance rouvre le parcours ; visible tout de suite, la sonde se corrige alors. Risque accepté.
- [`userLoggedIn` resté à `true` après une déconnexion volontaire] → relevé à la tâche 2.1. Si c'est le cas, la sonde prend la déconnexion pour une connexion : le module reste « déjà fait » et ne repropose rien. Accepté et consigné : après une déconnexion, c'est le client lui-même qui redemande la connexion, le module n'a pas à la rattraper ; on ne cherche pas d'autre signe dans les fichiers du client.
- [2FA activée sur le serveur] → l'utilisateur la saisit dans le client pendant l'attente (2 min, puis « Continuer d'attendre »).

## Migration Plan

Poste déjà connecté : `module_check` le constate, rien n'est refait. Retour arrière : revenir au commit précédent.
