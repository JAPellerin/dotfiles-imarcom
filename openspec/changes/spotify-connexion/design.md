## Context

Voir `proposal.md`. État actuel (`modules/63-spotify.sh`, archivé le 24 sept 2026) : `module_check` = paquet `spotify-client` + `spotify.list` identique au dépôt ; `module_install` déclare `SPOTIFY_LOGIN_MANUAL` à la première installation (variable `fresh`) ; `module_configure` vide.

Socle : `guided_login` et `open_detached` (`lib/connexion.sh`) ; sans `--secret` ni `--user`, le parcours ne lit rien dans 1Password et ne touche pas au presse-papiers (étapes 3 et 4 de `guided_login` sautées). Convention D5 de `openspec/changes/archive/2026-09-24-socle-connexion/design.md` : sonde dans `module_check`, parcours dans `module_configure`.

Relevés et hypothèses :

| Sujet | État |
|---|---|
| Signe de connexion (VM, 25 sept 2026, 1.2.95) | `~/.config/spotify/` **n'existe pas** avant la connexion, même client ouvert ; à la connexion par code QR (10:43:14), le client crée `prefs` **pendant qu'il tourne**, avec `autologin.username="…"` (valeur entre guillemets), `autologin.canonical_username`, `autologin.saved_credentials`, `autologin.blob` ; la sonde de D5 y est vraie |
| Écran de connexion (VM, 25 sept 2026, client **en anglais**) | à gauche « Millions of songs. Free on Spotify. », bouton **« Log in »** (ouvre le navigateur), « New to Spotify? Sign up free », « Settings » ; à droite le **code QR**, titre **« Scan code to log in »**, texte « On your mobile phone, open the camera or the QR scanner app to scan this code. » ; connexion par le code QR (décision de l'utilisateur, 25 sept 2026, à la place de « Continuer avec Google ») |
| Compte | lié au Google Workspace **personnel** (pas `…@imarcom.net`) ; aucun élément 1Password Spotify |
| Commande | `spotify` (`/usr/bin/spotify`, paquet `spotify-client`) |

## Goals / Non-Goals

**Goals :** Spotify connecté au premier passage sans que l'utilisateur ait à chercher où ; « connecté » constaté localement.

**Non-Goals :** lire un secret ; choisir le compte Google à la place de l'utilisateur ; réglages du client.

## Decisions

Numérotation : les décisions de ce change suivent celles du change `spotify` (D1 à D4, `openspec/changes/archive/2026-09-24-spotify/design.md`), que citent déjà les commentaires du module ; un « Dn » du module désigne donc sans ambiguïté l'un ou l'autre design, et l'en-tête du module renvoie aux deux.

### D5. Sonde `_spotify_logged_in`
Vraie si `~/.config/spotify/prefs` contient une ligne `autologin.username=` à valeur non vide (`grep -Eq '^autologin\.username="?[^"]+' -- "$SPOTIFY_PREFS"` : grep lit le fichier lui-même, sans tube, donc sans le piège de `grep -q` sous `pipefail`). Fichier absent → faux, **sans message** (`grep -s`, ou `[[ -f … ]] &&` : sinon « No such file » partirait au journal sur chaque machine neuve). Chemin : `SPOTIFY_PREFS="${SPOTIFY_PREFS:-${XDG_CONFIG_HOME:-$HOME/.config}/spotify/prefs}"`, surchargeable (tests) ; le client range ses réglages sous `$XDG_CONFIG_HOME` quand il est défini. Vérifié en VM le 25 sept 2026 (Context), dans les deux sens : à la **déconnexion** (« Se déconnecter », client laissé ouvert), le client réécrit `prefs` aussitôt et retire `autologin.username`, `autologin.saved_credentials` et `autologin.blob` ; seul `autologin.canonical_username` reste (valeur changée). La sonde sur `autologin.username` tient donc la déconnexion pour « pas connecté » ; `canonical_username`, qui survit, ne doit **pas** servir de signe.

### D6. Parcours dans `module_configure`
```
guided_login "Spotify" _spotify_logged_in "$SPOTIFY_LOGIN_MANUAL" \
  --open open_detached spotify ";" \
  -- "Dans Spotify, partie droite de l'écran : « Scan code to log in » (pas le bouton « Log in », qui ouvre le navigateur)." \
     "Scanner le code QR avec l'appareil photo du téléphone, puis confirmer la connexion sur le téléphone."
```
Sans secret : ni session 1Password requise, ni presse-papiers. Le client garde « Continuer avec Google » et le mot de passe : l'utilisateur reste libre de s'en servir, la sonde constate la connexion quelle qu'en soit la voie.

### D7. Étape manuelle
`module_install` ne déclare plus `SPOTIFY_LOGIN_MANUAL` ; la variable `fresh` disparaît. `guided_login` déclare l'étape si le parcours n'aboutit pas. Libellé inchangé. Le commentaire qui annonce `fresh` disparaît avec la variable. Deux commentaires du module deviennent faux et sont réécrits : celui de `module_install` (« L'étape de connexion est déclarée ici… », renvoi à D2 du change `spotify`) et celui de `module_configure` (« Rien à configurer : … compte hors périmètre »).
Commande d'ouverture : `spotify`, trouvée dans le `PATH` (`/usr/bin/spotify`, paquet `spotify-client`) — `open_detached` vérifie sa présence, les tests posent une commande factice en tête du `PATH`.

### D8. Tests (`tests/test-spotify.sh`)
Le fichier charge en plus `lib/op.sh` et `lib/connexion.sh`. `guided_login` réel, `has_gui` vrai, délais courts, `ui_choose` scripté, commande `spotify` factice en tête du `PATH` et `setsid` journalisés, `op` en doublure qui journalise tout appel (doublure obligatoire : le vrai `op` peut être installé sur la machine de test) ; `SPOTIFY_PREFS` dans le `HOME` du test ; doublure `wl-copy` qui journalise tout appel (le parcours est sans secret : le presse-papiers ne doit **jamais** être touché, ni copié ni vidé). Cas : sonde (ligne présente → vrai ; absente, vide, fichier absent → faux) ; `module_check` : paquet + fichier + connecté → 0, pas connecté → 1 ; `module_configure` : connexion pendant l'attente → aucune étape ; déjà connecté → aucune ouverture ; « Passer » → étape, retour 0 ; **aucun appel à `op`** dans tous les cas ; première installation → plus d'étape déclarée par `module_install`. Cas existants qui s'inversent ou changent, à reprendre nommément (lignes du fichier actuel) :
- l. 65, « étape de connexion au résumé, malgré les sous-shells » → devient « aucune étape déclarée par `module_install` » ;
- l. 66, `module_configure` → lance désormais `guided_login` : `has_gui` vrai, `ui_choose` scripté et délais courts (`CONNEXION_WAIT_SECONDS=1`, `CONNEXION_WAIT_INTERVAL=0.1`) à poser en tête du fichier, sinon il attend 2 minutes ; avec `prefs` absent et « Passer » scripté → étape déclarée, retour 0 ;
- l. 67, « module_check → déjà fait » → exige un `prefs` « connecté », posé juste avant ; de même pour les `module_check` à 0 de la section « spotify.list supprimé ou modifié » (l. 79, 82).

## Risks / Trade-offs

- [Format de `prefs` privé, changé par une mise à jour du client] → la sonde rend faux : le module reste « à faire » et repropose le parcours à chaque relance, sans rien casser ; la sonde se corrige alors.
- [Spotify déjà ouvert, déconnecté] → `open_detached spotify` ramène-t-il la fenêtre existante ou lance-t-il une seconde instance ? À observer à la tâche 2.1.
- [Le téléphone est connecté à un autre compte Spotify] → hors de portée de la sonde (elle constate une connexion, pas laquelle).

## Migration Plan

Poste déjà connecté : `module_check` le constate, rien n'est refait. Retour arrière : revenir au commit précédent.
