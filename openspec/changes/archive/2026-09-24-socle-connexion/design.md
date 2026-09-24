## Context

Voir `proposal.md`. Le socle fournit déjà les briques du parcours : `op_session_active` et `op_read` (`lib/op.sh`, secret sur stdout, jamais journalisé), `ui_wait` et `wait_for` (attente d'une sonde avec délai), `ui_choose`, `manual_step`, `apt_install`, `add_cleanup` et `cleanup_scope` (nettoyage à la sortie, y compris dans le sous-shell de `module_call`), `has_gui`.

État actuel, relevé le 24 sept 2026 :

| Endroit | Ce qui s'y fait |
|---|---|
| `modules/25-navigateur.sh`, `_nav_brave_sync` | sonde du profil de Brave (`_nav_brave_synced`) ; session 1Password ; `op_read` de la graine, 24 mots ; 25ᵉ mot calculé ; `apt_install wl-clipboard` ; `wl-copy` ; `_nav_open_brave` ; consigne en 3 points ; boucle `ui_wait` puis `ui_choose` « Continuer d'attendre » / « Passer » ; `wl-copy --clear` **seulement** quand la chaîne est rejointe ; délais `NAV_WAIT_SECONDS` (300) et `NAV_WAIT_INTERVAL` (2) |
| `_nav_open_brave` | fichier sentinelle `First Run`, trace au journal, `setsid -f brave-browser --no-first-run >/dev/null 2>&1 </dev/null`, avertissement si échec |
| `modules/10-1password.sh`, `_op_open_settings` | pour chaque page : trace au journal, `setsid -f xdg-open onepassword://settings/<page> …`, avertissement si échec ; vérifie d'abord `xdg-open` |
| Trap EXIT d'un sous-shell `( … )` sur Ctrl-C (essais du 24 sept 2026, bash) | sous-shell **au premier plan** (cas de `module_call` sous Ctrl-C) : SIGINT le termine (code 130) et le trap s'exécute — un nettoyage enregistré par `add_cleanup` s'exécute donc à l'interruption. Sous-shell **en arrière-plan** sans contrôle de tâches : SIGINT est ignoré, il va au bout de son travail (code 0) ; un premier essai qui l'employait ne prouvait rien (voir D7) |

Signes de connexion relevés pour la suite (changes par module, pas celui-ci) : Rocket.Chat `~/.config/Rocket.Chat/config.json`, `servers[].userLoggedIn == true` (constaté sur le client Windows de l'utilisateur) ; Spotify `~/.config/spotify/prefs` (`autologin.username`) et Thunderbird `logins.json` (`oauth://accounts.google.com`), à vérifier en VM.

## Goals / Non-Goals

**Goals :** un parcours unique, sûr pour le secret (jamais affiché, presse-papiers toujours vidé), jamais bloquant, sans `sudo` ni lecture de secret quand la connexion est déjà faite ; Brave Sync inchangé pour l'utilisateur, sauf le vidage du presse-papiers désormais systématique.

**Non-Goals :** les parcours de Rocket.Chat, Thunderbird, Spotify ; le parcours de `1password` lui-même ; un remplissage automatique ; un lien profond vers un élément dans l'app 1Password.

## Decisions

### D1. `lib/connexion.sh`, chargé par `setup.sh`
Deux helpers publics, `guided_login` et `open_detached`, dans un fichier à part (comme `lib/github.sh`, `lib/groups.sh`) chargé après `lib/module.sh` : il emploie `manual_step`, `op_read`, `ui_wait`, `ui_choose`, `apt_install`.

### D2. Interface de `guided_login`
```
guided_login <libellé> <sonde> <étape manuelle>
             [--secret <op://…> | --secret-fn <fonction>]
             [--user <op://…>]
             [--open <commande…> ;]
             [-- <consigne>…]
```
- `<sonde>` : fonction ou commande du module, sans `sudo` ni réseau, qui réussit quand la connexion est faite — la même que le module emploie dans `module_check` (D5).
- `--secret <op://…>` : lu par `op_read`. `--secret-fn <fonction>` : la fonction imprime le secret sur stdout et gère ses propres lectures ; elle avertit elle-même et échoue si elle ne peut pas le produire (cas de Brave Sync, D6).
- `--user <op://…>` : identifiant lu par `op_read` et **affiché** (`log_info`, donc aussi au journal) : ce n'est pas un secret, et le voir évite une deuxième copie. Illisible : avertissement, le parcours continue sans lui.
- `--open <commande…> ;` : la commande est exécutée telle quelle — typiquement `open_detached <app>`, ou une fonction du module qui prépare puis appelle `open_detached` (Brave). Le `;` isolé termine la commande, pour qu'elle puisse porter ses propres arguments.
- `-- <consigne>…` : une ligne par étape, numérotées par le helper.
Délais : `CONNEXION_WAIT_SECONDS` (120 — 300 à l'origine, ramené à 2 minutes par l'utilisateur le 24 sept 2026 après la validation en VM, D8) et `CONNEXION_WAIT_INTERVAL` (2), surchargeables (tests), qui remplacent `NAV_WAIT_*`.

### D3. Déroulé et garde-fous du secret
1. Sonde déjà vraie → `log_ok "<libellé> : déjà connecté"`, retour 0. Ni `op`, ni fenêtre, ni `sudo`.
2. Pas de session graphique (`has_gui` faux) → étape manuelle : ni presse-papiers ni fenêtre possibles.
3. `--secret` ou `--user` demandé sans session 1Password → `log_warn` + `manual_step`, retour 0.
4. Secret : lu **dans une variable** (`secret=$(op_read …)` ou `$(fn)`), jamais passé à `run` ni à `log_*` ; erreurs de `op` vers le journal (`2>>"$LOG_FILE"`), comme Brave Sync aujourd'hui. `wl-copy` absent → `apt_install wl-clipboard` (seul `sudo` possible, une fois par poste) ; installation en échec → avertissement + étape manuelle, comme un échec de copie (aujourd'hui, Brave Sync fait échouer le module dans ce cas : le helper ne le fait jamais). Copie par `printf '%s' "$secret" | wl-copy`, puis `unset secret`. **Avant** la copie : `add_cleanup "wl-copy --clear …"` — le vidage s'exécute à la sortie du sous-shell de `module_call`, donc aussi sur Ctrl-C (relevé du Context). Échec de copie → avertissement + étape manuelle.
5. Identifiant affiché, application ouverte, consigne numérotée, « Le script reprend dès que la connexion est constatée ; Ctrl-C pour abandonner. »
6. Boucle : `ui_wait "<libellé> : en attente (2 min au plus)" …` (durée affichée, D8) ; réussite → `wl-copy --clear`, `log_ok`, retour 0 ; délai → `ui_choose` « Continuer d'attendre » / « Passer (étape manuelle) » ; « Passer » (ou choix annulé) → vidage, `manual_step`, retour 0.
Le helper rend toujours 0, sauf pour une erreur de programmation (arguments invalides) : il ne fait jamais échouer le module. Le module qui l'emploie en déduit l'état par sa sonde (D5).
Vider le presse-papiers efface aussi ce que l'utilisateur y aurait copié entre-temps : accepté, c'est déjà le cas de Brave Sync.

### D4. `open_detached [--warn <message>] <commande…>`
Commande introuvable (`command -v`) → `log_warn "Impossible de lancer <commande> : l'ouvrir à la main."`, ou le `<message>` de `--warn` s'il est fourni (le module y nomme ce qu'il faut ouvrir quand la commande n'est qu'un intermédiaire, comme `xdg-open` ; ajouté à la contre-vérification du 24 sept 2026), retour 0. Sinon : trace `[hh:mm:ss] $ <commande> (détaché)` au journal, `setsid -f "$@" >/dev/null 2>&1 </dev/null` — l'application n'hérite ni du terminal ni du journal (elle y écrirait sinon ses propres traces tant qu'elle tourne, vu en VM avec 1Password) ; échec du lancement → même avertissement. Toujours 0.
`1password` : `_op_open_settings` garde sa vérification de `xdg-open` (message propre au module) et sa pause entre deux pages, et lance chaque page par `open_detached --warn "Impossible d'ouvrir onepassword://settings/<page> : aller dans les réglages de l'app à la main." xdg-open onepassword://settings/<page>` (message d'avant le change conservé). `navigateur` : `_nav_open_brave` garde le fichier `First Run` et appelle `open_detached brave-browser --no-first-run`.

### D5. Convention : la connexion fait partie de `module_check`
Décision de l'utilisateur (24 sept 2026). Un module qui emploie `guided_login` pour une connexion qui fait partie de son état attendu inclut **la même sonde** dans `module_check` : tant que l'utilisateur n'est pas connecté, le module reste « à faire », et une relance repropose le parcours sans rien retélécharger. Le module appelle `guided_login` dans `module_configure`, après ce qui installe et configure l'application. Consignée dans `CLAUDE.md` (contrat de module). Exception existante : Brave Sync, dans `navigateur`, dont `module_check` rend toujours 1 (module à questions, relancé à chaque fois) — inchangé.

### D6. Brave Sync sur le helper
`_nav_brave_sync` devient : Brave non installé → retour 0 ; sinon `guided_login "Brave Sync" _nav_brave_synced "$NAV_SYNC_MANUAL" --secret-fn _nav_brave_code --open _nav_open_brave ";" -- <les 3 consignes actuelles>`. `_nav_brave_code` reprend les contrôles actuels et leurs messages (session 1Password, lecture de `NAV_BRAVE_SYNC_REF`, 24 mots), calcule le 25ᵉ mot et imprime la phrase ; en cas d'échec, il avertit et rend 1, le helper déclare l'étape manuelle. Comportement visible inchangé, sauf le vidage du presse-papiers aussi sur « Passer » et sur interruption (delta de spec). `NAV_WAIT_*` disparaît au profit de `CONNEXION_WAIT_*`.
Exception au « jamais bloquant » (contre-vérification du 24 sept 2026) : une liste BIP39 versionnée absente ou incomplète est une **erreur d'installation** (dépôt incomplet), pas une étape de l'utilisateur. Aujourd'hui elle fait échouer le module (`_nav_brave_word25 || return 1`) ; passée par `--secret-fn`, elle deviendrait une simple étape manuelle et masquerait l'installation cassée. `_nav_brave_sync` appelle donc `_nav_brave_word25` **avant** `guided_login` et rend 1 s'il échoue (`log_error` actuel), comme aujourd'hui ; `_nav_brave_code` le recalcule ensuite.
Alternative écartée : laisser Brave Sync en place et n'ajouter que le helper — deux copies du même parcours (choix de l'utilisateur).

### D7. Tests
`tests/test-connexion.sh` : doublures de `op` (session et lecture, sur demande en échec), `wl-copy` (presse-papiers dans un fichier, `--clear` le vide), `apt_install`, `ui_choose` (réponse scriptée) ; `has_gui` forcé ; sonde = présence d'un fichier ; délais courts (`CONNEXION_WAIT_SECONDS=1`, `CONNEXION_WAIT_INTERVAL=0.1`) ; appels dans un sous-shell avec `cleanup_scope`, comme `module_call`. Cas : déjà connecté (ni `op`, ni ouverture, ni `apt_install`) ; connexion pendant l'attente (fichier créé en arrière-plan) → presse-papiers vidé, aucune étape ; délai puis « Passer » → vidé, étape déclarée, retour 0 ; délai puis « Continuer » puis connexion ; interruption → vidé : le sous-shell du parcours est lancé **au premier plan** et s'envoie SIGINT pendant l'attente (la sonde fait `kill -INT $BASHPID` au deuxième appel) ; attendus : code de sortie 130 **et** presse-papiers vide. Jamais un sous-shell en arrière-plan : sans contrôle de tâches, bash lui fait ignorer SIGINT, il irait au bout du délai et viderait le presse-papiers par « Passer », et le test passerait sans avoir été interrompu (vérifié le 24 sept 2026) ; sans session → étape, aucune ouverture ; `--secret-fn` en échec → étape ; `wl-copy` en échec → étape ; secret **absent** de la sortie et du journal, identifiant présent ; sans session graphique → étape ; `wl-copy` absent → `apt_install wl-clipboard` une fois ; `apt_install` en échec → étape, retour 0. `open_detached` : commande tracée au journal, sortie de la commande absente du journal, commande introuvable → avertissement, retour 0. Spinner (D8) : dans `tests/test-ui.sh`, sous un pseudo-terminal (`script`), un sous-shell au premier plan interrompu par SIGINT pendant un `ui_wait` ne laisse aucun processus derrière lui dans la session. `tests/test-navigateur.sh` : cas Brave Sync existants adaptés à `CONNEXION_WAIT_*`, plus « Passer » → presse-papiers vidé, et liste BIP39 absente → module en échec, aucune lecture 1Password.

### D8. Corrections après la validation en VM (24 sept 2026)
Constats du premier passage (tâche 4.1) : la connexion et la relance « déjà fait » sont bonnes, et sur Ctrl-C le presse-papiers est bien vidé (`wl-paste` : « Nothing is copied »). Mais :
- **Le spinner survit à Ctrl-C.** L'animation de `_ui_spinner` (`lib/ui.sh`, socle) tourne dans un sous-shell en arrière-plan, auquel bash fait ignorer SIGINT (`SigIgn: 0x6` relevé dans la VM : SIGINT et SIGQUIT). Au Ctrl-C, le runner et le module s'arrêtent, l'animation reste orpheline (rattachée à systemd) et continue de dessiner dans le terminal ; un second Ctrl-C n'y fait rien. Défaut du socle, présent dans tout `ui_spin` / `ui_wait` ; le parcours guidé le rend visible parce qu'il invite à faire Ctrl-C. Correction : l'animation mémorise le processus qui l'a lancée (`$BASHPID` avant le `&`) et s'arrête dès qu'il n'existe plus (`kill -0` à chaque image, toutes les 0,1 s). Le curseur est déjà rétabli par le nettoyage de sortie.
- **Le délai n'était pas visible.** Aucune attente n'avait atteint les 5 minutes (aucun « délai écoulé » au journal) : rien à l'écran ne disait combien de temps attendre. Le titre de l'attente porte désormais la durée maximale (« Brave Sync : en attente (2 min au plus) ») et le délai passe à **2 minutes** (décision de l'utilisateur).

## Risks / Trade-offs

- [Presse-papiers vidé alors que l'utilisateur y a copié autre chose pendant l'attente] → accepté (déjà le cas de Brave Sync) ; le vidage est ce qui garantit qu'un mot de passe n'y traîne pas.
- [Gestionnaire d'historique du presse-papiers (extension GNOME) qui garde le mot de passe] → hors de portée du script ; aucune n'est installée par le projet.
- [`wl-copy` sans session Wayland (X11)] → Ubuntu 26.04 est en Wayland ; sinon la copie échoue et le parcours devient une étape manuelle (D3).
- [Régression de Brave Sync ou de l'ouverture des réglages de 1Password] → mêmes consignes, mêmes sondes ; tests adaptés et validation en VM (tâches).
- [Mot de passe lu alors que l'utilisateur ne se connectera pas] → il ne vit que le temps du parcours, dans le presse-papiers ; vidé dans tous les cas.

## Migration Plan

Aucune donnée à migrer. `NAV_WAIT_SECONDS` / `NAV_WAIT_INTERVAL` n'étaient surchargés que par les tests. Retour arrière : revenir au commit précédent.
