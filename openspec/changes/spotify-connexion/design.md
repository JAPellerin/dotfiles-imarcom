## Context

Voir `proposal.md`. État actuel (`modules/63-spotify.sh`, archivé le 24 sept 2026) : `module_check` = paquet `spotify-client` + `spotify.list` identique au dépôt ; `module_install` déclare `SPOTIFY_LOGIN_MANUAL` à la première installation (variable `fresh`) ; `module_configure` vide.

Socle : `guided_login` et `open_detached` (`lib/connexion.sh`) ; sans `--secret` ni `--user`, le parcours ne lit rien dans 1Password et ne touche pas au presse-papiers (étapes 3 et 4 de `guided_login` sautées). Convention D5 de `openspec/changes/archive/2026-09-24-socle-connexion/design.md` : sonde dans `module_check`, parcours dans `module_configure`.

Relevés et hypothèses :

| Sujet | État |
|---|---|
| Signe de connexion (VM, 25 sept 2026, 1.2.95) | `~/.config/spotify/` **n'existe pas** avant la connexion, même client ouvert ; à la connexion par code QR (10:43:14), le client crée `prefs` **pendant qu'il tourne**, avec `autologin.username="…"` (valeur entre guillemets), `autologin.canonical_username`, `autologin.saved_credentials`, `autologin.blob` ; la sonde de D5 y est vraie |
| Parcours de connexion | écran de connexion **en deux parties** : l'une ouvre le navigateur pour s'authentifier, l'autre affiche le **code QR**, scanné avec l'application Spotify du téléphone (décision de l'utilisateur, 25 sept 2026, à la place de « Continuer avec Google ») |
| Compte | lié au Google Workspace **personnel** (pas `…@imarcom.net`) ; aucun élément 1Password Spotify |
| Commande | `spotify` (`/usr/bin/spotify`, paquet `spotify-client`) |

## Goals / Non-Goals

**Goals :** Spotify connecté au premier passage sans que l'utilisateur ait à chercher où ; « connecté » constaté localement.

**Non-Goals :** lire un secret ; choisir le compte Google à la place de l'utilisateur ; réglages du client.

## Decisions

Numérotation : les décisions de ce change suivent celles du change `spotify` (D1 à D4, `openspec/changes/archive/2026-09-24-spotify/design.md`), que citent déjà les commentaires du module ; un « Dn » du module désigne donc sans ambiguïté l'un ou l'autre design, et l'en-tête du module renvoie aux deux.

### D5. Sonde `_spotify_logged_in`
Vraie si `~/.config/spotify/prefs` contient une ligne `autologin.username=` à valeur non vide (`grep -Eq '^autologin\.username="?[^"]+' -- "$SPOTIFY_PREFS"` : grep lit le fichier lui-même, sans tube, donc sans le piège de `grep -q` sous `pipefail`). Fichier absent → faux. Chemin : `SPOTIFY_PREFS="${SPOTIFY_PREFS:-${XDG_CONFIG_HOME:-$HOME/.config}/spotify/prefs}"`, surchargeable (tests) ; le client range ses réglages sous `$XDG_CONFIG_HOME` quand il est défini. Vérifié en VM le 25 sept 2026 (Context).

### D6. Parcours dans `module_configure`
```
guided_login "Spotify" _spotify_logged_in "$SPOTIFY_LOGIN_MANUAL" \
  --open open_detached spotify ";" \
  -- "Dans Spotify, l'écran de connexion affiche un code QR (l'autre partie de l'écran ouvre le navigateur)." \
     "Scanner le code avec l'application Spotify du téléphone, puis confirmer sur le téléphone."
```
Sans secret : ni session 1Password requise, ni presse-papiers. Le client garde « Continuer avec Google » et le mot de passe : l'utilisateur reste libre de s'en servir, la sonde constate la connexion quelle qu'en soit la voie.

### D7. Étape manuelle
`module_install` ne déclare plus `SPOTIFY_LOGIN_MANUAL` ; la variable `fresh` disparaît. `guided_login` déclare l'étape si le parcours n'aboutit pas. Libellé inchangé. Deux commentaires du module deviennent faux et sont réécrits : celui de `module_install` (« L'étape de connexion est déclarée ici… », renvoi à D2 du change `spotify`) et celui de `module_configure` (« Rien à configurer : … compte hors périmètre »).
Commande d'ouverture : `spotify`, trouvée dans le `PATH` (`/usr/bin/spotify`, paquet `spotify-client`) — `open_detached` vérifie sa présence, les tests posent une commande factice en tête du `PATH`.

### D8. Tests (`tests/test-spotify.sh`)
Le fichier charge en plus `lib/op.sh` et `lib/connexion.sh`. `guided_login` réel, `has_gui` vrai, délais courts, `ui_choose` scripté, commande `spotify` factice en tête du `PATH` et `setsid` journalisés, `op` en doublure qui journalise tout appel (doublure obligatoire : le vrai `op` peut être installé sur la machine de test) ; `SPOTIFY_PREFS` dans le `HOME` du test. Cas : sonde (ligne présente → vrai ; absente, vide, fichier absent → faux) ; `module_check` : paquet + fichier + connecté → 0, pas connecté → 1 ; `module_configure` : connexion pendant l'attente → aucune étape ; déjà connecté → aucune ouverture ; « Passer » → étape, retour 0 ; **aucun appel à `op`** dans tous les cas ; première installation → plus d'étape déclarée par `module_install`. Cas existants adaptés : l'assertion « étape de connexion au résumé » après `module_install` (ligne 65 aujourd'hui) est retirée ; un `prefs` « connecté » est posé avant l'appel existant à `module_configure` et avant les `module_check` qui attendent 0.

## Risks / Trade-offs

- [Le téléphone est connecté à un autre compte Spotify] → hors de portée de la sonde (elle constate une connexion, pas laquelle).

## Migration Plan

Poste déjà connecté : `module_check` le constate, rien n'est refait. Retour arrière : revenir au commit précédent.
