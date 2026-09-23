## Why

Deux écarts se sont accumulés pendant la vague 2, relevés aux contre-vérifications du 23 sept 2026, et il faut les résorber avant la vague 3 et l'arrivée du laptop :

1. **La spec `module-1password` ne décrit plus le module.** Le correctif `464f5c5` (23 sept 2026, fait hors OpenSpec) a remplacé la ligne `SSH_AUTH_SOCK` ajoutée à `~/.commonrc` par un fragment `config/1password/commonrc.sh` lié dans `~/.commonrc.d/1password.sh` — la ligne finissait dans `~/.commonrc.bak`, puisque `1password` s'exécute avant `shell`, qui remplace `~/.commonrc` par un lien vers le dépôt. Le fragment est aussi devenu un critère de `module_check`. La spec parle toujours d'une « ligne présente une seule fois dans la config shell commune » et ne connaît pas ce critère.
2. **Treize renvois de commentaires pointent vers des dossiers qui n'existent plus.** Les en-têtes de `lib/`, `modules/` et `config/` renvoient à `openspec/changes/<nom>/…`, déplacé dans `openspec/changes/archive/<date>-<nom>/` à l'archivage. Chaque archive en ajoute ; la vague 3 en créerait cinq de plus.

## What Changes

- **Spec `module-1password`** alignée sur le code en place, sans changement de comportement :
  - « Agent SSH » : `SSH_AUTH_SOCK` fourni par un fragment de config shell lié dans `~/.commonrc.d/`, selon la convention de la vague 0 — plus une ligne ajoutée à `~/.commonrc` ; le fragment n'est lié que si l'application de bureau est installée ;
  - « Installation depuis le dépôt officiel » : le critère « déjà fait » inclut le fragment lié quand l'application est installée.
- **Renvois de commentaires corrigés** dans `lib/apt.sh`, `lib/files.sh`, `lib/groups.sh`, `config/cli-tools/commonrc.sh` et neuf modules (`21-terminal`, `22-cli-tools`, `25-navigateur`, `30-git`, `40-node`, `41-docker`, `42-dev-tools`, `51-vscode`, `52-claude-desktop`) : la spec par `openspec/specs/<capacité>/spec.md` (déjà la forme de `00-base`, `20-shell`, `lib/module.sh`), le design par son chemin d'archive `openspec/changes/archive/<date>-<nom>/design.md`.
- **Règle pour la suite**, notée dans `CLAUDE.md` : un commentaire de code renvoie à la spec principale, stable ; un renvoi au design d'un change en cours est mis à jour à son archivage.
- **Garde-fou** : nouveau `tests/test-refs.sh`, hors ligne — tout chemin `openspec/…` cité dans le code doit exister dans le dépôt ; un archivage qui oublie ses renvois fait échouer la suite de tests.

Hors périmètre : tout autre écart de spec. Aucun autre n'a été relevé ; les correctifs du socle du même jour (`fix(apt)` sur le verrou de dpkg) ne changent pas d'exigence.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-1password` : « Agent SSH » (fragment `~/.commonrc.d/1password.sh` au lieu d'une ligne dans `~/.commonrc`) et « Installation depuis le dépôt officiel » (fragment lié dans le critère « déjà fait » quand l'application est installée).

## Impact

- Aucun changement de comportement : le code de `1password` est déjà celui que décrira la spec (commit `464f5c5`, validé en VM).
- Fichiers touchés : `openspec/specs/module-1password/spec.md` (par sync), commentaires d'en-tête de 13 fichiers de `lib/`, `modules/` et `config/`, `CLAUDE.md` ; nouveau `tests/test-refs.sh`.
- Validation : suite de tests et ligne `shellcheck` de `CLAUDE.md` inchangées au vert ; plus aucun renvoi `openspec/changes/<nom>/` hors archive dans le code ; `./setup.sh --list` inchangé. Pas de passage en VM : aucun comportement ne change.
