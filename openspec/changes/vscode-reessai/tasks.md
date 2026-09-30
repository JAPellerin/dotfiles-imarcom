## 1. Module

- [ ] 1.1 `modules/51-vscode.sh` : `VSCODE_EXT_TRIES`, `VSCODE_EXT_PAUSE` et `_vscode_install_extension` (D1, D2) ; `module_configure` l'appelle sous un seul `ui_spin` ; `tests/test-vscode.sh` : cas de D3 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation

- [ ] 2.1 VM : `./setup.sh vscode` → extensions manquantes installées (dont `anthropic.claude-code`, en échec au test complet du 30 sept 2026), relance → « déjà fait » ; `openspec validate vscode-reessai --strict` vert ; consigner ici
