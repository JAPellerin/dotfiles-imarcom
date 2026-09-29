## Why

Dans le menu de `setup.sh`, décocher tous les modules présélectionnés un par un est fastidieux (demande de l'utilisateur, 29 sept 2026). `gum` 0.17 le permet déjà : `Ctrl+A` coche tout, un second `Ctrl+A` décoche tout (vérifié dans un pseudo-terminal le 29 sept 2026). Dans la source de `gum` 0.17.0 (`choose/choose.go`, contre-vérification du 29 sept 2026), `a`, `A` et `Ctrl+A` sont une seule et même liaison `ToggleAll`, et la ligne d'aide de `gum` sous le menu l'annonce déjà (« ctrl+a select all ») — mais elle est passée inaperçue : l'en-tête du menu, lu en premier, ne parle que d'« espace : cocher, entrée : valider ».

## What Changes

- L'en-tête du menu annonce les trois gestes : espace pour cocher ou décocher, `Ctrl+A` pour tout cocher ou tout décocher, entrée pour lancer.

Hors périmètre : ajouter des raccourcis à `gum` ; changer la présélection des modules non faits ; retirer la ligne d'aide de `gum` (elle reste, en doublon volontaire).

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `setup-runner` : exigence « Menu interactif par défaut » — le menu annonce le raccourci pour tout cocher ou tout décocher.

## Impact

- Modifiés : `setup.sh` (en-tête passé à `ui_choose_multi`), `tests/test-run.sh` (le `gum` factice trace son en-tête).
- Aucune dépendance nouvelle.
