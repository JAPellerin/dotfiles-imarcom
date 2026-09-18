## Context

Voir `proposal.md` (*Why*, *Impact*) pour la motivation et les contraintes vérifiées. Ce qui borne le design :

- Les trois réglages sont signés par l'app : seule l'interface peut les changer. Le script ne peut que **placer l'utilisateur au bon endroit** et **constater** le résultat.
- Avec l'intégration activée, **toute commande `op` déclenche une demande d'autorisation dans l'app** (observé le 17 sept, commit `b8acd4f` : `op signin` provoque l'invite ; `op whoami` échoue tant qu'elle n'est pas accordée). Une boucle qui appellerait `op` toutes les quelques secondes ferait surgir des invites pendant que l'utilisateur coche ses cases.
- Le socket `~/.1password/agent.sock` apparaît dès que « Use the SSH agent » est coché et l'app déverrouillée ; sa présence se teste sans solliciter l'app.
- État actuel : `_op_connect` affiche un chemin de menus, demande « Intégration activée ? », lance `op signin`, propose de réessayer ; `_op_ssh_agent` écrit `SSH_AUTH_SOCK` et déclare une `manual_step`. Les modules tournent en sous-shell, la session ouverte par `op signin` est partagée par `OP_SESSION_FILE`. Les modules n'appellent `gum` que par `lib/ui.sh`.

## Goals / Non-Goals

**Goals :**
- Un seul geste humain, sans aller-retour terminal ↔ app : l'app s'ouvre sur les réglages, l'utilisateur coche, le script reprend seul.
- Zéro invite d'autorisation parasite pendant l'attente ; une seule (`op signin`) à la fin.
- Sortie propre à tout moment (délai borné, choix explicite, Ctrl-C).
- Testable hors ligne avec des doublures (socket factice, `op` factice).

**Non-Goals :**
- Détecter si l'app est déjà connectée ou quel réglage manque précisément (l'app ne l'expose pas) : la consigne est affichée en entier et le diagnostic se fait a posteriori sur l'erreur de `op signin`.
- Inclure le socket dans `module_check` (voir proposal, hors périmètre).

## Decisions

### D1. Signaux d'attente : fichiers sur disque, jamais `op`
Toute commande `op` avec l'intégration active déclenche une demande d'autorisation dans l'app : la boucle d'attente ne lit que des fichiers. Deux sources (VM du 18 sept 2026, deux passages) :
- `~/.config/1Password/settings/settings.json` : absent au lancement (« Settings file missing, using defaults »), **créé à la première connexion** (« Lock state changed: Unlocked »), puis tenu à jour avec les réglages en clair — `security.authenticatedUnlock.enabled`, `developers.cliSharedLockState.enabled`, `sshAgent.enabled` (signés par l'app via `authTags`, mais lisibles). C'est l'état exact des cases.
- `~/.1password/agent.sock` : créé quand « Use the SSH agent » est coché (« SSH Agent has started »).
Prêt = intégration CLI cochée **et** agent présent, sondés toutes les 2 s, **stables depuis 3 s** (`OP_SETTLE`) : au 4e passage, un `op signin` lancé 0,2 s après « SSH Agent has started » a fait planter l'app (`traps: 1password trap int3` dans le journal noyau, « reading frame length: EOF » côté `op`), qui a perdu ses deux réglages et ses sockets ; 1 s et 60 s après, aucun problème. Bug de l'app, contourné. L'ordre des cases n'importe pas (au 1er passage l'agent avait été coché avant l'intégration CLI : `op signin` sans intégration tombe dans la saisie interactive d'adresse et a bloqué 42 s sur `/dev/null` — d'où aussi un garde-fou : pas de `op signin` dans le parcours app tant que l'intégration n'est pas cochée). Ensuite un seul `op signin` (autorisation dans l'app) puis `op whoami`.
Alternatives rejetées : sonder `op whoami` / `op signin` (rafale d'invites) ; `op account list` (sans invite observée, mais un processus `op` toutes les 2 s pour une information déjà sur disque) ; le socket `1Password-BrowserSupport.sock` (lié à l'extension navigateur, absent au 2e passage alors que `op` fonctionnait).

### D2. Ouverture de l'app par lien profond : seulement quand la fenêtre s'ouvre
Vérifié en VM (18 sept 2026, quatre essais) : un lien `onepassword://settings/<page>` **ne fait naviguer l'app que lorsqu'il (r)ouvre sa fenêtre** — passé en argument au lancement il ne fait que démarrer l'app (écran de connexion) ; reçu par l'app verrouillée, il est mis en attente et exécuté quand la fenêtre s'ouvre au déverrouillage ; reçu fenêtre déjà affichée, il est ignoré (« 1Password is already running, closing » sans navigation), même répété. Il n'existe pas de moyen propre de fermer la fenêtre depuis un script (GNOME/Wayland). Le module envoie donc `security` deux fois (lancement, puis 3 s après pour la mise en attente) : le réglage « Unlock using system authentication » est proposé dès la connexion. La page Developer reste **un clic manuel** (onglet dans la barre latérale des réglages), dit tel quel dans la consigne ; c'est le plancher réel. Lancement **détaché** (`setsid -f`, sorties vers `/dev/null`) : lancée comme enfant de `run`, l'app héritait du journal et y écrivait ses propres logs tant qu'elle tournait. Échec non bloquant : la consigne donne aussi les menus.
Alternatives rejetées : renvoyer `developers` périodiquement (essayé : ignoré fenêtre ouverte, et chaque envoi fait tourner les logs de l'app) ; fermer la fenêtre (pas d'API).

### D3. Attente bornée et menu de reprise
Helper générique `wait_for <secondes> <intervalle> <commande...>` dans `lib/core.sh` (boucle `sleep`, code 0 dès que la commande réussit, 1 à l'expiration), enveloppé par `ui_spin` pour l'animation. Délai par tour : 300 s (120 s expiraient pendant la première connexion, VM du 18 sept). Si l'agent est déjà là au démarrage (app configurée, simplement verrouillée — l'app se verrouille avec l'écran de veille et `op whoami` échoue alors, seul `op signin` déclenche le déverrouillage), le module passe droit à `op signin` sans rouvrir les réglages ni réafficher la consigne ; en cas d'échec, menu de reprise sans nouveau sondage. `module_check` reste « à faire » tant que la session est inactive : relancer le module coûte alors une seule invite de déverrouillage. À l'expiration, `ui_choose` : « Continuer d'attendre » (repart pour un tour, sans renvoyer de lien : voir D2), « Vérifier maintenant » (`op signin` immédiat, même sans socket — pour qui ne veut pas de l'agent ; refusé tant que l'intégration CLI n'est pas cochée, voir D1), « Connexion en terminal » (repli `op_signin_interactive`), « Abandonner » (échec du module avec le message existant). Ctrl-C pendant le spinner = abandon.
Alternative rejetée : attente infinie (impossible d'abandonner sans Ctrl-C, mauvaise expérience en cas de blocage).

### D4. Après `op signin` : diagnostic sans nouvelle sollicitation
Si `op whoami` échoue après `op signin`, afficher la première ligne d'erreur de `op` (déjà capturée dans un fichier temporaire), rappeler que « Integrate with 1Password CLI » et « Unlock using system authentication » doivent être cochés, et revenir au menu de reprise (D3) sans relancer `op signin` d'office. `op account add` n'est jamais appelé dans ce parcours ; si `op account list` montre un compte ajouté au CLI alors que l'intégration est active, l'avertir avec la commande `op account forget --all` (pas exécutée : décision de l'utilisateur).

### D5. Agent SSH : vérifié, plus déclaré
`_op_ssh_agent` garde `ensure_line` pour `SSH_AUTH_SOCK` et remplace `manual_step` par un `log_info` « prend effet dans un nouveau terminal ». La présence du socket ayant été constatée dans `_op_connect`, aucune étape manuelle n'est consignée. Si le parcours s'est terminé par « Vérifier maintenant » sans socket (utilisateur qui refuse l'agent), un `log_warn` le signale, sans `manual_step` non plus.

### D6. Tests hors ligne
`tests/test-op.sh` (ou `tests/test-core.sh` pour `wait_for`) : `wait_for` réussit dès que le fichier attendu apparaît (créé par un sous-shell différé), expire sinon ; `_op_connect` n'est pas testé de bout en bout (dépend de `gum` et de l'app), mais la fonction d'attente et le chemin `OP_AGENT_SOCK` surchargeable (`OP_AGENT_SOCK="${OP_AGENT_SOCK:-$HOME/.1password/agent.sock}"`) permettent de simuler l'apparition du socket. Le parcours réel reste couvert par le test 5.4 de `setup-socle` en VM.

## Risks / Trade-offs

- [Le lien `onepassword://` n'ouvre pas la page voulue si l'app n'est pas encore connectée, ou `xdg-open` échoue] → consigne complète à l'écran (avec le chemin des menus) ; vérifié en VM : le lien n'est exécuté qu'à l'ouverture de la fenêtre, d'où le double envoi de D2 et la page Developer laissée en clic manuel.
- [Autorisation « CLI » redemandée par l'app à chaque nouveau processus `op`] → non observé (VM du 18 sept) : une seule invite à `op signin`, `op whoami` répond ensuite directement tant que l'app est déverrouillée ; après verrouillage (veille), `op whoami` échoue et `op signin` redemande une invite.
- [L'utilisateur ne veut pas de l'agent SSH] → « Vérifier maintenant » permet de terminer sans socket ; avertissement, pas d'échec.
- [`op signin` trop tôt après l'activation des réglages fait planter l'app (trap int3, réglages perdus)] → stabilisation de 3 s avant `op signin` ; si ça se reproduit malgré tout, l'utilisateur recoche les deux cases et relance `setup.sh 1password`.
- [Socket présent mais app verrouillée] → sans conséquence : `op signin` déclenche le déverrouillage/l'autorisation dans l'app.
- [`sleep` en boucle sous `ui_spin` et Ctrl-C] → `ui_spin` restaure déjà le curseur ; vérifier que l'interruption se propage (code 130) et se traduit par « abandon ».

## Open Questions

- ~~Le lien `onepassword://settings/developers` positionne-t-il bien la page quand l'app vient d'être lancée par ce même lien ?~~ Non (VM du 18 sept) : il ne navigue que dans une app déverrouillée ; d'où le signal de connexion de D2.
_Aucune : les quatre essais en VM du 18 sept 2026 ont tranché le comportement des liens profonds._
