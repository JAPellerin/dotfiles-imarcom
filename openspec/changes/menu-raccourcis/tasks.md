## 1. Menu

- [ ] 1.1 `setup.sh` : en-tête de D1 dans `select_from_menu` ; `tests/test-run.sh` : `gum` factice qui trace `--header`, assertion « Ctrl+A » (D2) ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre
- [ ] 1.2 Essai réel (WSL) : `./setup.sh` → l'en-tête annonce Ctrl+A ; `Ctrl+A` deux fois décoche tout ; `a` deux fois fait de même (même liaison dans la source, design) ; puis `Échap` ; `openspec validate menu-raccourcis --strict` vert
