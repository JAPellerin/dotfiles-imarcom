## 1. Helpers

- [x] 1.1 `lib/connexion.sh` : `open_detached` (D4) et `guided_login` (D2, D3), en-tête dans le style des autres `lib/*.sh` (rôle, garde-fous du secret, renvoi au design) ; chargé par `setup.sh` après `lib/module.sh` ; vérifier `shellcheck lib/connexion.sh setup.sh` propre
- [x] 1.2 `tests/test-connexion.sh` : les cas de D7 pour les deux helpers ; vérifier `bash tests/test-connexion.sh` vert, puis qu'une mutation le fait échouer (cas « interruption » par un sous-shell au premier plan qui s'envoie SIGINT, code 130 attendu — D7 ; retirer le `add_cleanup` du vidage → cas « interruption » en échec ; journaliser le secret → cas « secret jamais visible » en échec)

## 2. Modules existants

- [x] 2.1 `modules/25-navigateur.sh` : Brave Sync sur `guided_login` (D6) — `_nav_brave_code` (contrôles et messages actuels, 25ᵉ mot, phrase sur stdout), `_nav_brave_sync` réduit à la vérification de la liste BIP39 (D6) puis à l'appel du helper, `_nav_open_brave` sur `open_detached`, `NAV_WAIT_*` retiré ; `tests/test-navigateur.sh` : délais `CONNEXION_WAIT_*`, cas existants inchangés sur le fond, nouveaux cas « Passer » → presse-papiers vidé et liste BIP39 absente → module en échec (D6) ; vérifier `bash tests/test-navigateur.sh` vert
- [x] 2.2 `modules/10-1password.sh` : `_op_open_settings` sur `open_detached` (D4, vérification de `xdg-open` et pause entre deux pages conservées) ; vérifier `bash tests/test-1password.sh` vert

## 3. Vérification d'ensemble et documentation

- [x] 3.1 `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre ; `bash tests/test-refs.sh` vert ; `openspec validate socle-connexion --strict` vert
- [x] 3.2 `CLAUDE.md` : `guided_login` et `open_detached` (`lib/connexion.sh`) dans la liste des helpers du socle, avec la convention D5 (la sonde de connexion entre dans `module_check`, le parcours est lancé dans `module_configure`) ; `ROADMAP.md` : `socle-connexion` fait (date)

## 4. Validation en VM

- [ ] 4.1 VM (snapshot « vierge », mémoire fixe) : bootstrap → `base`, `1password` → l'app 1Password s'ouvre sur ses réglages comme avant (non-régression D4) ; `navigateur` avec Brave → Brave s'ouvre, le code est dans le presse-papiers, la chaîne rejointe est constatée, presse-papiers vidé (`wl-paste` vide) ; relance → « déjà rejointe », aucune lecture 1Password ; second essai sur un profil neuf : « Passer » → `wl-paste` vide, étape au résumé ; troisième essai : Ctrl-C pendant l'attente → `wl-paste` vide ; aucun secret dans `~/.local/state/dotfiles/setup-*.log` ; consigner ici
