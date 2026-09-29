## Why

Relevé en VM à la validation de `projets` (29 sept 2026) : avec l'intégration de l'application 1Password, l'autorisation de la CLI `op` expire après une dizaine de minutes sans commande `op`, et `op whoami` — que le socle utilise pour constater la session — répond alors « not signed in » **sans rien demander**. Dans une exécution longue (ici `navigateur`, 17 minutes d'attentes guidées), le module `1password` a bien ouvert la session au départ, mais les modules suivants qui lisent des secrets la trouvent fermée et se rabattent sur leurs étapes manuelles. La réouverture existe déjà (`op signin` : fenêtre d'autorisation de l'application ; sans l'application, connexion en terminal) : il manque de la déclencher au bon moment.

## What Changes

- Le **runner**, avant d'exécuter (`module_install`, `module_configure`) un module qui dépend, directement ou non, de `1password`, constate la session ; si elle est fermée alors que le module `1password` a réussi ou était déjà fait dans cette exécution, il la **rouvre** par le parcours de connexion du module `1password` (fenêtre d'autorisation de l'application, ou connexion en terminal sans elle). Le constat se fait avant `module_install` **et de nouveau avant `module_configure`** : la plupart des modules lisent leurs secrets à la configuration, après une installation qui peut être longue (archive Thunderbird, apt) — au plus une réouverture avant chacune des deux étapes.
- Échec ou refus de la réouverture : avertissement, puis le module s'exécute quand même (il déclare ses étapes manuelles, comme aujourd'hui).
- Jamais dans `module_check` ni dans l'affichage du menu : le constat d'état ne demande toujours rien.

Hors périmètre : modifier les modules qui lisent 1Password (aucun ne change) ; les commandes des projets (`--snapshot-projets`, `--pull-projets`), qui exécutent déjà `1password` d'abord.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `setup-runner` : nouvelle exigence — session 1Password rouverte avant un module qui en dépend.

## Impact

- Modifiés : `setup.sh` (`run_modules`, fonction de dépendance à `1password`), `tests/test-run.sh`, jeu factice `tests/fixtures/modules/` (un module qui dépend de `1password`, un `1password` factice qui sait « rouvrir »).
- `modules/10-1password.sh` : le runner appelle son parcours de connexion (`_op_connect`) par `module_call` ; le message d'échec « les modules qui ont besoin de secrets seront sautés » (`_op_no_session`) est faux dans ce contexte (le module s'exécute quand même) : le parcours ne l'affiche plus quand il est appelé par le runner.
- Interaction : une fenêtre d'autorisation de 1Password peut apparaître en cours d'exécution, avant un module qui lit des secrets.
