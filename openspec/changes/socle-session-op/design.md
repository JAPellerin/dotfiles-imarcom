## Context

Voir `proposal.md`. Relevé en VM (29 sept 2026, journal de la tâche 2.2 de `projets`) : `1password` fait à 12:41 (session ouverte), dernière commande `op` vers 12:46 (`navigateur`, Brave Sync), `projets` à 13:00 → « aucune session 1Password » ; verrouillage de l'application à 60 min, écran non verrouillé ; `op whoami` par SSH → « account is not signed in ». Au lancement suivant, le runner a exécuté `1password` (non fait : `module_check` exige la session), dont le parcours `_op_connect` → `_op_connect_via_app` → agent prêt → `_op_try_signin` (`op signin`, fenêtre d'autorisation) a rouvert la session.

Code : `run_modules` (`setup.sh`) enchaîne `module_check`, puis `module_install` et `module_configure` par `module_call` ; `MOD_DEPS` donne les dépendances directes ; `_op_connect` (`modules/10-1password.sh`) rend 0 si une session est active ou a été ouverte. `op_session_active` (`lib/op.sh`) = `op whoami` (recharge d'abord `OP_SESSION_FILE`), sans rien demander. **Relevé 0.1 (29 sept 2026)** : 11 min sans commande `op` → `op whoami` : « account is not signed in », code 1 ; `op signin` rouvre par l'application.

## Goals / Non-Goals

**Goals :** un module qui lit des secrets trouve la session ouverte, même après une longue attente ; un seul endroit dans le code ; aucune question hors de l'exécution d'un module.

**Non-Goals :** prolonger la session par des appels périodiques ; changer `op_session_active` (il sert à `module_check`, qui ne doit rien demander) ; modifier les modules consommateurs.

## Decisions

### D1. Où : `run_modules`, avant `module_install` et de nouveau avant `module_configure`
Seulement pour un module qui va réellement s'exécuter (pas « déjà fait », pas sauté, pas indisponible). Deux constats et non un : les secrets se lisent presque toujours dans `module_configure` (`git`, `vault`, `vpn`, `thunderbird`, `projets`), après une installation qui peut dépasser la dizaine de minutes ; un `op whoami` de plus ne coûte rien (contre-vérification, 29 sept 2026). Fonction `_op_session_ensure_for <module>`, appelée aux deux endroits. Condition : le module n'est pas `1password` ; il en dépend (fermeture transitive de `MOD_DEPS`, fonction `_depends_on_op` sur le modèle de `_closure_of`) ; `RESULT[1password]` vaut `fait`, `a-terminer` ou `deja-fait` (le module `1password` a tourné ou était fait dans cette exécution ; échoué ou absent → rien) ; `op_session_active` faux.
Alternative écartée (utilisateur, 29 sept 2026) : un helper `op_session_ensure` appelé par chaque module avant ses lectures — une dizaine d'appels à ajouter et à tester.

### D2. Comment : le parcours du module `1password`
`module_call "${MOD_FILE[1password]}" _op_connect` : avec l'application, `op signin` par elle (fenêtre d'autorisation) ; sans elle (WSL), `op signin` en terminal ; la session est écrite dans `OP_SESSION_FILE`, que les sous-shells des modules rechargent. Message avant : « Session 1Password expirée : réouverture avant « <module> » (autoriser la demande de 1Password). » Échec (code non nul) → `log_warn` « Session 1Password non rouverte : « <module> » s'exécute sans secrets (étapes manuelles possibles). », et le module s'exécute. **Message d'échec du parcours** : `_op_connect` appelle `_op_no_session` (« les modules qui ont besoin de secrets seront sautés… »), vrai depuis `module_configure` de `1password`, faux depuis le runner. `_op_connect` prend un argument facultatif `--quiet` (ou point d'entrée `_op_reconnect`) : même parcours, sans ce message ; le runner l'emploie, `module_configure` de `1password` garde le message.
Dépendance à un nom interne du module `1password` (`_op_connect`) : documentée dans les deux fichiers ; le jeu factice des tests en fournit une.

### D3. Tests (`tests/test-run.sh`)
Jeu factice `tests/fixtures/modules/` : `10-1password.sh` gagne `_op_connect` (pose un marqueur de session, trace « reconnexion ») ; nouveau module factice qui dépend de `1password` et trace s'il voit la session, dans `module_install` **et** dans `module_configure`. Doublure `op` du test (`whoami` selon un marqueur) : session fermée → réouverture tracée avant le module ; ouverte → aucune ; session fermée par `module_install` du module factice (il retire le marqueur) → réouverture tracée avant `module_configure` ; module sans lien → aucune ; `_op_connect` en échec → avertissement, module exécuté ; `--list` et menu → aucune réouverture. Les assertions existantes sur le jeu factice restent vertes (nouveau module à compter dans `--all`).

## Risks / Trade-offs

- [Fenêtre d'autorisation inattendue en milieu d'exécution] → message juste avant ; c'est la même fenêtre que celle du module `1password`.
- [Appel d'une fonction interne d'un autre module] → contrat documenté ; si `_op_connect` change de nom, les tests du runner (jeu factice) ne le verraient pas : un commentaire le signale dans `modules/10-1password.sh`.
- [Durée d'expiration exacte inconnue (~10 min)] → la condition est l'état constaté, pas une durée.
