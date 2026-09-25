## Why

Validation en VM de `rocketchat-connexion` (25 sept 2026) : après « Passer » au parcours de connexion, le résumé final affiche « ✔ rocketchat fait » alors que la connexion reste à faire et que `module_check` rend toujours « à faire » (`./setup.sh --list`). Le runner classe « fait » tout module dont `module_install` et `module_configure` ont réussi, sans regarder s'il a déclaré une étape manuelle : le résumé dit « terminé » là où l'utilisateur a encore quelque chose à faire, et l'étape n'apparaît que plus bas, dans la liste « Étapes manuelles restantes ».

Le cas n'est pas propre à Rocket.Chat : tout module qui déclare une étape manuelle (`manual_step`, directement ou par `guided_login` / `group_relogin_step`) est concerné — Brave Sync, Spotify, Thunderbird, VPN, groupe `docker`, terminal, Obsidian, outils de dev, VS Code, Claude Desktop.

## What Changes

- **Nouvel état de résultat « à terminer »** (valeur interne `a-terminer`) : un module dont `module_install` et `module_configure` ont réussi **et** qui a déclaré au moins une étape manuelle pendant cette exécution est affiché au résumé en **jaune**, `! <module> à terminer (étape manuelle)`, au lieu de `✔ <module> fait`. Décision de l'utilisateur (25 sept 2026) : un état distinct plutôt qu'une mention ajoutée à « fait ».
- L'état « à terminer » **ne bloque pas** les modules qui en dépendent (seuls « échoué », « sauté » et « non disponible ici » bloquent, comme aujourd'hui) et **ne rend pas** le code de sortie non nul.
- Le journal consigne `RESUME <module> : a-terminer`.
- Inchangé : la liste consolidée « Étapes manuelles restantes », les états « déjà fait », « sauté », « non disponible ici », « échoué » ; un module qui échoue reste « échoué » même s'il a déclaré une étape manuelle.

Hors périmètre : relancer `module_check` après `module_configure` pour décider de l'état (voir design) ; changer le texte ou le moment des étapes manuelles déclarées par les modules.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `setup-runner` : l'exigence « Isolation des échecs et résumé final » gagne l'état « à terminer » pour un module réussi qui a déclaré une étape manuelle.

## Impact

- Modifiés : `setup.sh` (`run_modules`, `print_summary`, `result_label`), `tests/test-run.sh` (l'assertion « résumé : a fait » devient « à terminer » : le module factice `a` déclare une étape manuelle), et au besoin un module factice sans étape manuelle sous `tests/fixtures/modules/` pour garder un cas « fait ».
- Aucun module touché : ils déclarent déjà leurs étapes par `manual_step`.
- Aucun paquet, aucun réseau, aucun secret.
- Validation : tests hors ligne ; un passage en VM confirme le rendu (ex. « Passer » au parcours de `rocketchat`).
- Docs : `ROADMAP.md` (change de socle ajouté à la vague 4).
