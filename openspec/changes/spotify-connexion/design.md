## Context

Voir `proposal.md`. État actuel (`modules/63-spotify.sh`, archivé le 24 sept 2026) : `module_check` = paquet `spotify-client` + `spotify.list` identique au dépôt ; `module_install` déclare `SPOTIFY_LOGIN_MANUAL` à la première installation (variable `fresh`) ; `module_configure` vide.

Socle : `guided_login` et `open_detached` (`lib/connexion.sh`) ; sans `--secret` ni `--user`, le parcours ne lit rien dans 1Password et ne touche pas au presse-papiers (étapes 3 et 4 de `guided_login` sautées). Convention D5 de `openspec/changes/archive/2026-09-24-socle-connexion/design.md` : sonde dans `module_check`, parcours dans `module_configure`.

Relevés et hypothèses :

| Sujet | État |
|---|---|
| Signe de connexion | `~/.config/spotify/prefs`, ligne `autologin.username=…` après connexion (design de `socle-connexion`, Context) — **à vérifier en VM**, ainsi que le moment où le client l'écrit |
| Parcours de connexion du client Linux 1.2.x | la page de connexion propose « Continuer avec Google » ; **à vérifier en VM** si Google s'ouvre dans le navigateur par défaut (l'extension 1Password y remplit) ou dans une fenêtre du client (rien n'y remplit) |
| Compte | Google Workspace **personnel** (pas `…@imarcom.net`) ; aucun élément 1Password Spotify |
| Commande | `spotify` (`/usr/bin/spotify`, paquet `spotify-client`) |

## Goals / Non-Goals

**Goals :** Spotify connecté au premier passage sans que l'utilisateur ait à chercher où ; « connecté » constaté localement.

**Non-Goals :** lire un secret ; choisir le compte Google à la place de l'utilisateur ; réglages du client.

## Decisions

### D1. Sonde `_spotify_logged_in`
Vraie si `~/.config/spotify/prefs` contient une ligne `autologin.username=` à valeur non vide (`grep -Eq '^autologin\.username="?[^"]+' -- "$SPOTIFY_PREFS"` : grep lit le fichier lui-même, sans tube, donc sans le piège de `grep -q` sous `pipefail`). Fichier absent → faux. Chemin surchargeable par `SPOTIFY_PREFS` (tests). **À vérifier en VM** (tâche 0.1) ; si le signe diffère (autre clé, autre fichier), D1 est corrigé avant le code.

### D2. Parcours dans `module_configure`
```
guided_login "Spotify" _spotify_logged_in "$SPOTIFY_LOGIN_MANUAL" \
  --open open_detached spotify ";" \
  -- "Dans Spotify : « Continuer avec Google »." \
     "Choisir le compte Google personnel (pas celui d'Imarcom) ; 1Password remplit dans le navigateur." \
     "Revenir à Spotify une fois la page Google acceptée."
```
Sans secret : ni session 1Password requise, ni presse-papiers. Les consignes sont ajustées après la tâche 0.1 (libellés exacts du client, en français si le client l'est).
Si la tâche 0.1 montre que Google s'ouvre **dans une fenêtre du client** (où l'extension ne remplit rien), la consigne le dit et le parcours reste sans secret : aucun élément 1Password n'identifie ce compte personnel (relevé du 24 sept 2026) ; en ajouter un serait une décision de l'utilisateur, hors de ce change.

### D3. Étape manuelle
`module_install` ne déclare plus `SPOTIFY_LOGIN_MANUAL` ; la variable `fresh` disparaît. `guided_login` déclare l'étape si le parcours n'aboutit pas. Libellé inchangé.

### D4. Tests (`tests/test-spotify.sh`)
`guided_login` réel, `has_gui` vrai, délais courts, `ui_choose` scripté, commande `spotify` et `setsid` en doublures journalisées, `op` en doublure qui journalise tout appel. Cas : sonde (ligne présente → vrai ; absente, vide, fichier absent → faux) ; `module_check` : paquet + fichier + connecté → 0, pas connecté → 1 ; `module_configure` : connexion pendant l'attente → aucune étape ; déjà connecté → aucune ouverture ; « Passer » → étape, retour 0 ; **aucun appel à `op`** dans tous les cas ; première installation → plus d'étape déclarée par `module_install`. Cas existants adaptés.

## Risks / Trade-offs

- [Le client n'écrit `prefs` qu'à la fermeture] → vérifié en VM (tâche 0.1) ; sinon, la consigne demande de fermer Spotify une fois connecté (la sonde le constate alors), et D1/D2 le disent.
- [Mauvais compte Google choisi] → hors de portée de la sonde (elle constate une connexion, pas laquelle) ; la consigne nomme le compte.

## Migration Plan

Poste déjà connecté : `module_check` le constate, rien n'est refait. Retour arrière : revenir au commit précédent.
