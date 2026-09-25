## Context

Motivation : voir `proposal.md` (Why). État actuel de `setup.sh` :

- `run_modules` range chaque module dans `RESULT[<nom>]` : `deja-fait` si `module_check` réussit, `fait` si `module_install` puis `module_configure` réussissent, `echoue` sinon ; `saute` et `indisponible` avant toute exécution. Un dépendant est sauté si une dépendance est `echoue`, `saute` ou `indisponible`.
- `manual_step` (`lib/module.sh`) écrit `<MODULE_NAME><TAB><texte>` dans `MANUAL_STEPS_FILE`, un fichier temporaire propre à l'exécution (créé au chargement de `lib/module.sh`, supprimé en sortie), hérité par les sous-shells de `module_call`. `guided_login` et `group_relogin_step` passent par `manual_step`.
- `print_summary` affiche une ligne par module (symbole, couleur, libellé de `result_label`), consigne `RESUME <nom> : <état>` au journal, puis liste le fichier des étapes manuelles.

Contrainte : `module_install` et `module_configure` tournent dans deux sous-shells distincts (`module_call`) ; aucune variable n'en remonte au runner. Seul le fichier des étapes manuelles fait le lien.

## Goals / Non-Goals

**Goals:**
- Le résumé ne dit plus « fait » pour un module dont une étape manuelle reste à faire.
- Aucun module à modifier : le signal est l'étape manuelle déjà déclarée.

**Non-Goals:**
- Distinguer une étape « facultative » d'une étape « requise » : toute étape déclarée compte.
- Réafficher l'état réel (`module_check`) au résumé.

## Decisions

### D1 — Le signal : une ligne du module dans le fichier des étapes manuelles

Après la réussite de `module_install` et `module_configure`, le runner cherche dans `MANUAL_STEPS_FILE` une ligne qui commence par `<nom><TAB>` (comparaison exacte du champ, pas d'expression régulière construite à partir du nom). Présente → `a-terminer` ; absente → `fait`.

Suffisant parce que le fichier est propre à l'exécution et que chaque module ne s'y exécute qu'une fois : une ligne à son nom a forcément été écrite pendant son passage. L'échec l'emporte : si `module_install` ou `module_configure` échoue, l'état reste `echoue`, quelle que soit l'étape déclarée.

Lecture du fichier sans `grep -q` sous `pipefail` en tube (piège SIGPIPE → 141) : `grep` sur le fichier directement, ou `awk` avec le nom passé par `-v`.

**Alternative écartée — relancer `module_check` après `module_configure`** : ce serait l'état réel, mais faux pour le cas du groupe (`docker`, `claude-desktop`) : `user_in_group` lit la base des groupes, donc `module_check` passe alors que la session doit encore être rouverte ; coûteux aussi pour les sondes (1Password, fichiers d'apps). Et un `module_check` qui échoue juste après une installation réussie mélangerait deux sens (« à terminer » et « installation incomplète »).

**Alternative écartée — mention ajoutée à « fait »** : décision de l'utilisateur (25 sept 2026), un état distinct en jaune se voit mieux.

### D2 — Rendu et journal

- Valeur interne `a-terminer` (sans accent, comme `deja-fait`), consignée telle quelle : `RESUME <nom> : a-terminer`.
- Écran : symbole `!`, couleur jaune (`$_C_YELLOW`, déjà utilisée pour « sauté »), libellé de `result_label` : `à terminer (étape manuelle)`. Le libellé porte la mention plutôt que `RESULT_WHY`, réservé aux raisons d'un saut.
- Ordre des colonnes et `pad` inchangés : `! rocketchat     à terminer (étape manuelle)`.
- Le commentaire de `declare -A RESULT` liste la nouvelle valeur.

### D3 — Sans effet sur les dépendants ni sur le code de sortie

Le `case` qui bloque les dépendants ne connaît que `echoue|saute|indisponible` : `a-terminer` n'y entre pas, rien à changer. `print_summary` ne met `failed=1` que pour `echoue` : idem. Les deux points sont couverts par des tests (D4) plutôt que par du code.

### D4 — Tests

`tests/test-run.sh` : le factice `a` déclare déjà une étape manuelle dans `module_configure` → l'assertion `✔ a              fait` devient `! a              à terminer (étape manuelle)`, plus `RESUME a : a-terminer` au journal et le code de sortie 0 (déjà vérifié). Cas « fait » : `b`, `base`, `1password`, `gui` n'en déclarent pas, leurs assertions restent. Cas « dépendant d'un module à terminer » : le factice `b` déclare une étape manuelle **seulement si** une variable d'environnement de test le demande (ex. `FIXTURE_B_MANUAL=1`), puis `setup a` sur un état vierge → `b` « à terminer », `a` exécuté. Cas « échec après une étape manuelle » : le factice `echec` déclare une étape avant d'échouer, ou la même variable sur un factice qui échoue ; le choix du factice se fait à l'implémentation, sans ajouter de module factice si l'on peut l'éviter (`tests/test-module.sh` et `--list` comptent les factices de `tests/fixtures/modules/`).

## Risks / Trade-offs

- [Étape déclarée par précaution alors que tout est fait] (ex. `terminal` : « rouvrir la session » à chaque installation) → le module est « à terminer » à cette exécution, puis « déjà fait » à la suivante. C'est le sens voulu : l'étape reste à faire tant que l'utilisateur ne l'a pas faite.
- [Module sans `MODULE_NAME` au moment de `manual_step`] → la ligne porte `?` et le module reste « fait ». Le contrat de module impose `MODULE_NAME` (`tests/test-module.sh`) : non constaté aujourd'hui.
- [Un outil externe lit `RESUME … : fait` dans le journal] → aucun connu ; le journal est lu à la main.

## Migration Plan

Aucune donnée ni configuration à migrer : l'état n'est calculé que pendant l'exécution. Retour arrière : revenir au commit précédent.
