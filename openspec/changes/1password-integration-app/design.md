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

### D1. Signal d'attente : le socket de l'agent SSH, pas `op`
La boucle d'attente ne teste que `[[ -S ~/.1password/agent.sock ]]` (toutes les 2 s). L'agent SSH est le dernier des trois réglages dans la consigne, sa présence vaut « l'utilisateur a fini ». Puis un seul `op signin` (autorisation dans l'app) suivi de `op whoami`.
Alternatives rejetées : sonder `op whoami` / `op signin` en boucle (rafale d'invites d'autorisation) ; sonder un socket interne app ↔ CLI (chemin non documenté, instable).

### D2. Ouverture de l'app par liens profonds, une fois par page
Observé en VM le 18 sept 2026 : un lien profond ne navigue que dans une app **déjà connectée et déverrouillée** ; envoyé au lancement, il ne fait que démarrer l'app (écran de connexion). Le module ouvre donc `security` au lancement, puis **rouvre `security` dès que l'app est connectée**, signal détecté sans solliciter l'app : l'app crée `~/.config/1Password/settings/` à l'instant de la première connexion (« Lock state changed: Unlocked » → « Settings file changed »), avant tout réglage. Observé une fois : si le signal ne vient pas, l'attente continue et l'utilisateur navigue à la main (état antérieur). Le lien `developers` n'est rejoué que sur « Continuer d'attendre ». Lancement **détaché** (`setsid -f`, sorties vers `/dev/null`) : lancée comme enfant de `run`, l'app héritait du journal et y écrivait ses propres logs tant qu'elle tournait (57 Ko, descripteurs ouverts). Le socket `1Password-BrowserSupport.sock` n'apparaît qu'à l'activation de « Integrate with 1Password CLI » (c'est le canal `op` ↔ app) : pas un signal de connexion.
`xdg-open onepassword://settings/security`, puis (après un court délai, le temps que l'app démarre) `xdg-open onepassword://settings/developers`. Ce sont les liens de la doc officielle d'intégration ; le paquet `1password` enregistre le gestionnaire `x-scheme-handler/onepassword`. `xdg-open` est appelé via `run` (sortie au journal), échec non bloquant : si le lien n'ouvre rien, la consigne à l'écran suffit (elle donne aussi le chemin des menus). Si l'app n'est pas encore connectée, elle affiche d'abord son écran de connexion ; l'utilisateur s'y connecte puis va dans les réglages (le lien n'est pas rejoué automatiquement, il l'est à la demande « vérifier maintenant / continuer d'attendre »).
Alternative rejetée : lancer `1password --silent` puis décrire les menus (c'est l'état actuel, plus de navigation pour l'utilisateur).

### D3. Attente bornée et menu de reprise
Helper générique `wait_for <secondes> <intervalle> <commande...>` dans `lib/core.sh` (boucle `sleep`, code 0 dès que la commande réussit, 1 à l'expiration), enveloppé par `ui_spin` pour l'animation. Délai par tour : 300 s (120 s expiraient pendant la première connexion, VM du 18 sept). Si l'agent est déjà là au démarrage (app configurée, simplement verrouillée — l'app se verrouille avec l'écran de veille et `op whoami` échoue alors, seul `op signin` déclenche le déverrouillage), le module passe droit à `op signin` sans rouvrir les réglages ni réafficher la consigne ; en cas d'échec, menu de reprise sans nouveau sondage. `module_check` reste « à faire » tant que la session est inactive : relancer le module coûte alors une seule invite de déverrouillage. À l'expiration, `ui_choose` : « Continuer d'attendre » (rejoue le lien `developers` et repart pour un tour), « Vérifier maintenant » (`op signin` immédiat, même sans socket — pour qui ne veut pas de l'agent), « Connexion en terminal » (repli `op_signin_interactive`), « Abandonner » (échec du module avec le message existant). Ctrl-C pendant le spinner = abandon.
Alternative rejetée : attente infinie (impossible d'abandonner sans Ctrl-C, mauvaise expérience en cas de blocage).

### D4. Après `op signin` : diagnostic sans nouvelle sollicitation
Si `op whoami` échoue après `op signin`, afficher la première ligne d'erreur de `op` (déjà capturée dans un fichier temporaire), rappeler que « Integrate with 1Password CLI » et « Unlock using system authentication » doivent être cochés, et revenir au menu de reprise (D3) sans relancer `op signin` d'office. `op account add` n'est jamais appelé dans ce parcours ; si `op account list` montre un compte ajouté au CLI alors que l'intégration est active, l'avertir avec la commande `op account forget --all` (pas exécutée : décision de l'utilisateur).

### D5. Agent SSH : vérifié, plus déclaré
`_op_ssh_agent` garde `ensure_line` pour `SSH_AUTH_SOCK` et remplace `manual_step` par un `log_info` « prend effet dans un nouveau terminal ». La présence du socket ayant été constatée dans `_op_connect`, aucune étape manuelle n'est consignée. Si le parcours s'est terminé par « Vérifier maintenant » sans socket (utilisateur qui refuse l'agent), un `log_warn` le signale, sans `manual_step` non plus.

### D6. Tests hors ligne
`tests/test-op.sh` (ou `tests/test-core.sh` pour `wait_for`) : `wait_for` réussit dès que le fichier attendu apparaît (créé par un sous-shell différé), expire sinon ; `_op_connect` n'est pas testé de bout en bout (dépend de `gum` et de l'app), mais la fonction d'attente et le chemin `OP_AGENT_SOCK` surchargeable (`OP_AGENT_SOCK="${OP_AGENT_SOCK:-$HOME/.1password/agent.sock}"`) permettent de simuler l'apparition du socket. Le parcours réel reste couvert par le test 5.4 de `setup-socle` en VM.

## Risks / Trade-offs

- [Le lien `onepassword://` n'ouvre pas la page voulue si l'app n'est pas encore connectée, ou `xdg-open` échoue] → consigne complète à l'écran (avec le chemin des menus), lien rejoué sur « Continuer d'attendre » ; à vérifier en VM (tâche dédiée).
- [Autorisation « CLI » redemandée par l'app à chaque nouveau processus `op`] → non observé (VM du 18 sept) : une seule invite à `op signin`, `op whoami` répond ensuite directement tant que l'app est déverrouillée ; après verrouillage (veille), `op whoami` échoue et `op signin` redemande une invite.
- [L'utilisateur ne veut pas de l'agent SSH] → « Vérifier maintenant » permet de terminer sans socket ; avertissement, pas d'échec.
- [Socket présent mais app verrouillée] → sans conséquence : `op signin` déclenche le déverrouillage/l'autorisation dans l'app.
- [`sleep` en boucle sous `ui_spin` et Ctrl-C] → `ui_spin` restaure déjà le curseur ; vérifier que l'interruption se propage (code 130) et se traduit par « abandon ».

## Open Questions

- ~~Le lien `onepassword://settings/developers` positionne-t-il bien la page quand l'app vient d'être lancée par ce même lien ?~~ Non (VM du 18 sept) : il ne navigue que dans une app déverrouillée ; d'où le signal de connexion de D2.
- Le dossier `settings/` est-il créé à la connexion sur toute version de l'app ? Observé une fois (app 8.11.x, 18 sept 2026) ; à confirmer au second passage en VM.
