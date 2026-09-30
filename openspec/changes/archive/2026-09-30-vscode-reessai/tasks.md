## 1. Module

- [x] 1.1 `modules/51-vscode.sh` : `VSCODE_EXT_TRIES`, `VSCODE_EXT_PAUSE` et `_vscode_install_extension` (D1, D2) ; `module_configure` l'appelle sous un seul `ui_spin` ; `tests/test-vscode.sh` : cas de D3 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre — **fait le 30 sept 2026** : 41 assertions (dont trois tentatives avant l'échec, panne passagère rattrapée au 2ᵉ essai sans échec affiché)

## 2. Validation

- [x] 2.1 VM : `./setup.sh vscode` → extensions manquantes installées (dont `anthropic.claude-code`, en échec au test complet du 30 sept 2026), relance → « déjà fait » ; `openspec validate vscode-reessai --strict` vert ; consigner ici — **fait le 30 sept 2026** : `anthropic.claude-code` désinstallée → réinstallée en une tentative, « Extensions VS Code : 18 présentes » ; relance → « Déjà fait » (le cas 503 reste couvert par les tests : impossible à provoquer sur le vrai magasin)
