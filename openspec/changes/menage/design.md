## Context

Voir `proposal.md`. Relevé du 23 sept 2026 (`grep -rn "openspec/changes/" lib modules config`, archives exclues) : 13 renvois morts dans 13 fichiers. Deux formes correctes existent déjà dans le code : la spec principale (`modules/00-base.sh`, `modules/20-shell.sh`, `lib/module.sh`, `bootstrap.sh` → `openspec/specs/<capacité>/spec.md`) et le design archivé (`lib/files.sh` ligne 8 → `openspec/changes/archive/2026-09-18-shell/design.md`). Les corps de modules citent les décisions par leur numéro (« D3 ») : ces citations restent justes tant que l'en-tête désigne le bon design.

Côté `1password`, le code est déjà le bon (commit `464f5c5`, validé en VM le 23 sept 2026) : `config/1password/commonrc.sh` lié par `link_config` vers `$SHELL_COMMON_RC_DIR/1password.sh`, constaté par `config_linked` dans `module_check` quand le paquet `1password` est installé. Seule la spec est en retard.

## Goals / Non-Goals

**Goals :** une spec `module-1password` qui décrit le module tel qu'il est ; plus aucun renvoi mort ; un garde-fou qui empêche les suivants.

**Non-Goals :** toucher au comportement d'un module ; réécrire les commentaires au-delà de leurs renvois ; corriger des renvois dans les artefacts archivés (ils décrivent l'état de leur époque).

## Decisions

### D1. Deux formes de renvoi, selon la cible
- **Spec** → `openspec/specs/<capacité>/spec.md` : stable, suit les syncs, ne bouge pas à l'archivage.
- **Design** → `openspec/changes/archive/<date>-<nom>/design.md` : le design n'a pas d'équivalent principal, son chemin d'archive est définitif.
Pour les 13 renvois : chaque `openspec/changes/<nom>/specs/<cap>/spec.md` devient `openspec/specs/<cap>/spec.md`, chaque `openspec/changes/<nom>/design.md` devient le chemin d'archive de ce change (les dates se lisent dans `openspec/changes/archive/`). Les numéros de décision cités (« D6 », « D3 ») sont conservés.
Alternative écartée : ne renvoyer qu'à la spec — on perdrait le « pourquoi » des choix techniques, que seuls les designs portent (ex. `--allow-downgrades`, `-oDPkg::Lock::Timeout`).

### D2. Pendant un change en cours, le renvoi vise `openspec/changes/<nom>/`
Un module en développement n'a pas encore de spec principale ni d'archive : il renvoie à son change actif, comme aujourd'hui. Ces renvois sont corrigés **dans la même opération que l'archivage** du change. Règle notée dans `CLAUDE.md`, section OpenSpec.

### D3. Garde-fou : `tests/test-refs.sh`
Un test hors ligne relève, dans `lib/`, `modules/`, `config/`, `setup.sh` et `bootstrap.sh`, chaque chemin qui commence par `openspec/` et vérifie qu'il existe dans le dépôt (les formes groupées `{a,b}` sont développées). Un change archivé sans corriger ses renvois fait échouer `run-all.sh` : l'oubli se voit au lieu de s'accumuler. Il accepte les renvois vers un change actif (le dossier existe), donc ne gêne pas le développement (D2).
Alternative écartée : la règle de `CLAUDE.md` seule — c'est exactement ce qui a laissé 13 renvois mourir.

### D4. Spec `1password` : deux exigences modifiées, comportement décrit tel quel
« Agent SSH » décrit le fragment lié et son indépendance vis-à-vis de l'ordre `1password`/`shell` ; « Installation depuis le dépôt officiel » ajoute le fragment au critère « déjà fait » quand l'application est installée. Les scénarios existants sont conservés, reformulés seulement là où ils nommaient la « ligne ».

## Risks / Trade-offs

- [Le test D3 bute sur un chemin écrit dans un commentaire à titre d'exemple] → aucun cas aujourd'hui ; un tel exemple s'écrirait sans le préfixe `openspec/`.
- [Un design archivé est renommé] → jamais fait par ce projet ; le test le verrait.

## Migration Plan

Aucune : commentaires et spec seulement. Le poste déjà configuré par l'ancien code (ligne dans `~/.commonrc`) n'existe pas : la WSL n'a pas l'application de bureau, et la VM repart du snapshot.
