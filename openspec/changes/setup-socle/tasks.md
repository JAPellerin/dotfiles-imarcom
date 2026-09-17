## 1. Dépôt et outillage

- [x] 1.1 Initialiser le dépôt git (`git init`, branche `main`, `.gitignore`) et vérifier `git status` propre hors artefacts OpenSpec — fait le 15 sept 2026, poussé sur `JAPellerin/dotfiles-imarcom`
- [x] 1.2 Installer `gum` et `shellcheck` dans la WSL de développement et vérifier `gum --version` et `shellcheck --version` — fait le 16 sept 2026 (gum 0.17.0-1, shellcheck 0.11.0-2, dépôts Ubuntu)
- [x] 1.3 Mettre à jour `CLAUDE.md` avec les décisions D1–D10 (résumé) et les commandes `shellcheck`, `setup.sh --list`, `setup.sh <module>` ; vérifier que le fichier ne répète pas `design.md` — fait (14–15 sept), `ROADMAP.md` ajouté ; revérifier les commandes en 3.6

## 2. Bibliothèque `lib/`

- [x] 2.1 `lib/core.sh` : `log_info/warn/error/step` (écran + journal), `die`, `require_not_root`, `sudo_keepalive` (+ `trap` de nettoyage), `run` / `run_sudo` (sortie dans `$LOG_FILE`, dernières lignes du journal en cas d'échec), `has_gui` (faux si `$WSL_DISTRO_NAME`), `LOG_FILE` sous `~/.local/state/dotfiles/` ; `tests/lib.sh` (`assert_*`) et `tests/test-core.sh` : `has_gui` faux dans la WSL, journal créé, `run` d'une commande qui échoue renvoie non nul et journalise
- [x] 2.2 `lib/apt.sh` : `apt_update_once`, `apt_install <paquets...>` (n'installe que les manquants), `apt_add_repo` deb822 idempotent, `pkg_installed`, tous via `run_sudo` ; `tests/test-apt.sh` : un double appel à `apt_add_repo` ne réécrit pas le `.sources` et ne relance pas `apt update`
- [x] 2.3 `lib/ui.sh` : wrappers `ui_choose`, `ui_choose_multi`, `ui_confirm`, `ui_input`, `ui_password`, `ui_spin`, `ui_header` autour de `gum` (aucune redirection globale : `gum` garde le terminal) ; vérifier manuellement chaque wrapper depuis un shell interactif (`tests/demo-ui.sh`)
- [x] 2.4 `lib/op.sh` : `op_session_active`, `op_read <op://...>` (échoue sans session, n'écrit rien dans le journal), `op_signin_interactive` ; `tests/test-op.sh` : `op_read` sans session → code non nul et message « lancer setup.sh 1password »
- [x] 2.5 `lib/module.sh` : `manual_step <texte>` (fichier temporaire d'étapes), chargement d'un module en sous-shell, validation des métadonnées (nom = fichier, champs requis dont `MODULE_GROUP`) ; `tests/test-module.sh` avec un factice `tests/fixtures/modules/` sans `MODULE_DESC` : rejeté en nommant le fichier
- [x] 2.6 Passer `shellcheck` sur `lib/*.sh` et `tests/*.sh` sans avertissement

## 3. Runner `setup.sh`

- [x] 3.1 Squelette : refus root, `sudo -v` + keepalive, chargement de `lib/`, découverte de `$MODULES_DIR` (défaut `modules/`), `--list` ; vérifier `setup.sh --list` affiche groupe, nom, description, état et que `sudo setup.sh` refuse
- [x] 3.2 Résolution des dépendances : tri topologique, détection de cycle et de dépendance inconnue, `1password` avancé devant les non-dépendances ; `tests/test-deps.sh` avec des factices sous `tests/fixtures/modules/` (`a` dep `b`, cycle `c`↔`d`, dépendance inconnue) : ordre et erreurs corrects
- [x] 3.3 Exécution : `module_check` → `install` → `configure`, isolation des échecs, saut des dépendants, saut des `MODULE_NEEDS_GUI` sans GUI ; `tests/test-run.sh` avec un factice qui échoue : dépendants sautés et code de sortie non nul
- [x] 3.4 Menu par défaut : `gum choose --no-limit` avec libellé `[groupe] nom — description — état`, présélection des non faits (`--selected`), « déjà faits » décochés, mode ciblé par noms et `--all`, erreur sur nom inconnu listant les valides ; vérifier `setup.sh navigateurz` et le menu manuellement
- [x] 3.5 Résumé final : table fait / déjà fait / sauté / échoué, section « Étapes manuelles restantes », chemin du journal en cas d'échec ; vérifier le rendu avec les modules factices
- [x] 3.6 `shellcheck setup.sh tests/*.sh` sans avertissement ; vérifier que les commandes documentées dans `CLAUDE.md` existent (dont `bash tests/test-*.sh`) ; les modules factices restent versionnés sous `tests/fixtures/` (jeux `modules/`, `contrat/`, `cycle/`, `dep-inconnue/`)

## 4. Modules `base` et `1password`

- [x] 4.1 `modules/00-base.sh` (`MODULE_GROUP=systeme`) : `apt update && upgrade` (après `ui_confirm`, oui par défaut) puis paquets listés dans la spec ; vérifier dans la WSL que deux exécutions successives donnent « fait » puis « déjà fait »
- [x] 4.2 `modules/10-1password.sh` (`MODULE_GROUP=systeme`) — installation : dépôt officiel + `debsig`, `1password-cli` toujours, `1password` si `has_gui` ; vérifier dans la WSL que seul le CLI est installé et que `op --version` fonctionne
- [x] 4.3 `modules/10-1password.sh` — connexion : `op whoami`, parcours « intégration app » (guidage + confirmation) et parcours `op account add` / `op signin` avec export de session ; vérifier dans la WSL le parcours manuel jusqu'à `op whoami` réussi
- [x] 4.4 `modules/10-1password.sh` — agent SSH : ligne `SSH_AUTH_SOCK` idempotente dans la config shell commune quand l'app est installée, `manual_step` pour l'activation ; vérifier que deux exécutions ne dupliquent pas la ligne — vérifié par tests/test-core.sh (ensure_line) et essai à blanc ; parcours réel avec l'app en 5.4

## 5. Bootstrap et test de bout en bout

- [ ] 5.1 `bootstrap.sh` : `apt install git gum` si absents, clone HTTPS ou `git pull`, refus si `~/dotfiles` n'est pas un dépôt, `exec bash setup.sh < /dev/tty` ; `shellcheck` propre et vérifier localement `bash bootstrap.sh` avec un `~/dotfiles` déjà cloné (parcours `git pull`)
- [ ] 5.2 Pousser `main` sur le dépôt GitHub `JAPellerin/dotfiles-imarcom` (créé, vide, remote SSH `git@github.com:JAPellerin/dotfiles-imarcom.git`), avec les URL raw + clone HTTPS en constantes dans `bootstrap.sh` ; vérifier `curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | head -1` renvoie le shebang
- [ ] 5.3 Créer la VM Hyper-V Ubuntu 26.04 Desktop et prendre un snapshot « vierge » ; vérifier que le snapshot se restaure
- [ ] 5.4 Test de bout en bout dans la VM : `curl -fsSL <url-raw>/bootstrap.sh | bash` → menu → `base` + `1password` (app + CLI, intégration, agent SSH) ; vérifier le résumé final, `op whoami`, `echo $SSH_AUTH_SOCK` dans un nouveau shell, puis restaurer le snapshot et relancer pour vérifier l'idempotence (« déjà fait » partout)
