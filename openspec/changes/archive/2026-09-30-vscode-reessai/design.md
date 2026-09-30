## Context

Voir `proposal.md`. Code actuel (`modules/51-vscode.sh`, `module_configure`) : pour chaque extension manquante, `ui_spin "Extension VS Code : $id" run "$VSCODE_BIN" --install-extension "$id"`, échec → `log_error` qui la nomme, retour 1. `ui_spin` affiche un rapport d'échec en rouge (`_run_report_failure`) à chaque commande qui échoue ; `run`, appelé sous l'animation (`_UI_SPINNING`), ne rapporte rien lui-même mais trace la commande et sa sortie au journal.

## Goals / Non-Goals

**Goals :** une panne passagère du magasin ne fait plus échouer le module ; un seul message à l'écran par extension (réussite ou échec final) ; journal complet des tentatives.

**Non-Goals :** trier les erreurs selon leur nature ; helper de reprise dans `lib/` ; reprise de l'installation des paquets apt (déjà gérée par apt).

## Decisions

### D1. Reprise dans la commande animée
Fonction `_vscode_install_extension <id>` : boucle de `VSCODE_EXT_TRIES` tentatives (`run "$VSCODE_BIN" --install-extension "$id"`), `sleep "$VSCODE_EXT_PAUSE"` entre deux, rend 0 à la première réussite, 1 après la dernière. `module_configure` l'appelle sous **un seul** `ui_spin "Extension VS Code : $id"` : une animation pendant toutes les tentatives, un seul « ✔ » ou un seul rapport d'échec (celui de la dernière). Chaque tentative laisse sa ligne `$ …` et sa sortie au journal (par `run`).
Alternative écartée : un `ui_spin` par tentative — chaque échec intermédiaire afficherait un rapport rouge, pour une panne rattrapée ensuite.

### D2. Nombre et pause
`VSCODE_EXT_TRIES="${VSCODE_EXT_TRIES:-3}"`, `VSCODE_EXT_PAUSE="${VSCODE_EXT_PAUSE:-10}"` (surchargeables : tests à 0 s). Pire cas pour une extension vraiment introuvable : ~20 s d'attente de plus avant l'échec, acceptable pour une liste de 18 extensions installées une fois.

### D3. Tests (`tests/test-vscode.sh`)
Faux `code` : une extension listée dans `extensions-refusees-une-fois` échoue au premier appel (le nom est alors retiré de ce fichier), puis réussit. Cas : refusée une fois → module réussi, deux appels pour elle, extension installée ; toujours refusée (`extensions-refusees`, cas existant) → trois appels pour elle, échec qui la nomme. `VSCODE_EXT_PAUSE=0`.

## Risks / Trade-offs

- [Panne du magasin plus longue que ~20 s] → le module échoue comme avant, en nommant l'extension ; relancer `setup.sh vscode` plus tard.
- [Aucun message à l'écran entre deux tentatives] → voulu (D1) ; le journal les trace.
