## Context

Voir `proposal.md`. `select_from_menu` (`setup.sh`) appelle `ui_choose_multi "Modules à exécuter (espace : cocher, entrée : valider) :" …`, qui lance `gum choose --no-limit --header …`. Relevé le 29 sept 2026 (gum 0.17, pseudo-terminal) : `Ctrl+A` une fois → tout coché ; deux fois → rien de coché. Source de `gum` 0.17.0 (`choose/choose.go`) : `ToggleAll` = `a`, `A`, `Ctrl+A` (une seule liaison, donc même comportement pour `a` — le relevé initial qui disait le contraire est à refaire, tâche 1.2) ; la ligne d'aide de `gum` (`--show-help`, actif) liste « x toggle · ctrl+a select all · enter submit ». Le `gum` factice de `tests/test-run.sh` ignore ses arguments.

## Goals / Non-Goals

**Goals :** le raccourci est visible là où l'on en a besoin.

**Non-Goals :** modifier `gum` ou son aide ; changer `ui_choose_multi` (générique, d'autres appels n'ont pas besoin de ce texte).

## Decisions

### D1. Texte de l'en-tête
« Modules à exécuter — espace : cocher/décocher · Ctrl+A : tout cocher/tout décocher · entrée : lancer » : une ligne, les trois gestes, dans l'ordre où on s'en sert. Écarté : une ligne d'aide séparée sous le menu — `gum` en affiche déjà une, qui nomme `ctrl+a`, et elle n'a pas suffi ; l'en-tête est lu en premier, on y met les gestes en clair.

### D2. Test
Le `gum` factice écrit son option `--header` dans un fichier du test ; assertion : l'en-tête contient « Ctrl+A ».

## Risks / Trade-offs

- [Terminal étroit : en-tête tronqué] → `gum` coupe la ligne ; les gestes essentiels sont en tête.
