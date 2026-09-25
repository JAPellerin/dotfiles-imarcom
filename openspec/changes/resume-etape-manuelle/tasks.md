## 1. Runner

- [x] 1.1 `setup.sh` : état `a-terminer` (D1, D2) — après la réussite de `module_install` et `module_configure`, ligne `<nom><TAB>…` cherchée dans `MANUAL_STEPS_FILE` (sans `grep -q` en tube sous `pipefail`, sans expression régulière construite du nom) → `a-terminer`, sinon `fait` ; `print_summary` : `!` en jaune ; `result_label` : `à terminer (étape manuelle)` ; commentaire de `declare -A RESULT` à jour ; blocage des dépendants et code de sortie inchangés (D3). Vérifier : `MODULES_DIR=tests/fixtures/modules ./setup.sh a` (WSL, état factice vierge) → `! a              à terminer (étape manuelle)` et code 0.
- [x] 1.2 `tests/test-run.sh` et factices (D4) : assertion `a` → « à terminer (étape manuelle) » et `RESUME a : a-terminer` au journal ; `b` déclare une étape seulement si `FIXTURE_B_MANUAL=1` → `b` « à terminer », `a` exécuté quand même ; `echec` déclare une étape avant d'échouer → « échoué », `dependant` sauté, étape listée ; assertions « fait » existantes (`base`, `1password`, `gui`) intactes. Vérifier : `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre.

## 2. Validation et documentation

- [ ] 2.1 VM : relancer `./setup.sh rocketchat` client déconnecté, « Passer » → résumé `! rocketchat     à terminer (étape manuelle)` en jaune, étape listée dessous, journal `RESUME rocketchat : a-terminer` ; relance après connexion → « déjà fait » ; consigner ici.
- [ ] 2.2 `ROADMAP.md` : vague 4, change de socle `resume-etape-manuelle` (constat de la validation de `rocketchat-connexion`), fait (date) ; `openspec validate resume-etape-manuelle --strict` vert.
