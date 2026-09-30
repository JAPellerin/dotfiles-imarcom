## Why

Au test d'installation complète en VM (30 sept 2026), le module `vscode` a échoué : VS Code s'est installé, mais `code --install-extension anthropic.claude-code` a reçu `Server returned 503` du magasin d'extensions de Microsoft, une panne passagère de leur côté. Une seule tentative suffit à faire échouer le module, alors qu'un second essai quelques secondes plus tard aurait très probablement réussi ; l'utilisateur doit relancer `setup.sh vscode` à la main. Décision de l'utilisateur (30 sept 2026) : réessayer avant d'échouer.

## What Changes

- `modules/51-vscode.sh` : chaque extension manquante est installée en **3 tentatives au plus**, espacées de **10 secondes** ; le module n'échoue, en nommant l'extension, qu'après la dernière. Une seule animation par extension ; chaque tentative est tracée au journal.
- Spec `module-vscode`, exigence « Extensions tirées d'une liste versionnée » : l'échec n'est retenu qu'après plusieurs tentatives ; nouveau scénario « Panne passagère du magasin ».
- `tests/test-vscode.sh` : extension refusée une fois puis acceptée → module réussi, deux appels ; toujours refusée → trois appels, échec nommé.

Hors périmètre : distinguer les erreurs passagères (503) des erreurs définitives (identifiant inconnu) — une extension introuvable coûte simplement ~20 s de plus avant l'échec ; toute reprise généralisée dans `lib/` (un seul module en a besoin).

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-vscode` : installation des extensions avec reprise sur échec.

## Impact

- Modifiés : `modules/51-vscode.sh`, `tests/test-vscode.sh`.
- Aucun changement de `module_check`, de la liste d'extensions ni des paquets. Réseau : au plus deux appels de plus au magasin par extension en échec.
