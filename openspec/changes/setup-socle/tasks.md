## 1. Dépôt et outillage

- [ ] 1.1 Initialiser le dépôt git (`git init`, branche `main`, `.gitignore`) et vérifier `git status` propre hors artefacts OpenSpec
- [ ] 1.2 Installer `gum` et `shellcheck` dans la WSL de développement et vérifier `gum --version` et `shellcheck --version`
- [ ] 1.3 Mettre à jour `CLAUDE.md` avec les décisions D1–D10 (résumé) et les commandes `shellcheck`, `setup.sh --list`, `setup.sh <module>` ; vérifier que le fichier ne répète pas `design.md`

## 2. Bibliothèque `lib/`

- [ ] 2.1 `lib/core.sh` : `log_info/warn/error/step`, `die`, `require_not_root`, `sudo_keepalive` (+ `trap` de nettoyage), `has_gui`, `LOG_FILE` sous `~/.local/state/dotfiles/` ; vérifier par un script de test que `has_gui` retourne faux dans la WSL et que le journal est créé
- [ ] 2.2 `lib/apt.sh` : `apt_update_once`, `apt_install <paquets...>` (n'installe que les manquants), `apt_add_repo` deb822 idempotent, `pkg_installed` ; vérifier qu'un double appel à `apt_add_repo` ne réécrit pas le `.sources` et ne relance pas `apt update`
- [ ] 2.3 `lib/ui.sh` : wrappers `ui_choose`, `ui_choose_multi`, `ui_confirm`, `ui_input`, `ui_password`, `ui_spin`, `ui_header` autour de `gum` ; vérifier manuellement chaque wrapper depuis un shell interactif
- [ ] 2.4 `lib/op.sh` : `op_session_active`, `op_read <op://...>` (échoue sans session, n'écrit rien dans le journal), `op_signin_interactive` ; vérifier `op_read` sans session → code non nul et message « lancer setup.sh 1password »
- [ ] 2.5 `lib/module.sh` : `manual_step <texte>` (fichier temporaire d'étapes), chargement d'un module en sous-shell, validation des métadonnées (nom = fichier, champs requis) ; vérifier qu'un module sans `MODULE_DESC` est rejeté en nommant le fichier
- [ ] 2.6 Passer `shellcheck` sur `lib/*.sh` sans avertissement

## 3. Runner `setup.sh`

- [ ] 3.1 Squelette : refus root, `sudo -v` + keepalive, chargement de `lib/`, découverte de `modules/`, `--list` ; vérifier `setup.sh --list` affiche nom, description, état et que `sudo setup.sh` refuse
- [ ] 3.2 Résolution des dépendances : tri topologique, détection de cycle et de dépendance inconnue, `1password` avancé devant les non-dépendances ; vérifier avec trois modules factices (`a` dep `b`, cycle `c`↔`d`) que l'ordre et les erreurs sont corrects
- [ ] 3.3 Exécution : `module_check` → `install` → `configure`, isolation des échecs, saut des dépendants, saut des `MODULE_NEEDS_GUI` sans GUI ; vérifier avec un module factice qui échoue que les dépendants sont sautés et le code de sortie est non nul
- [ ] 3.4 Menu par défaut : `gum choose --no-limit` avec état, non-présélection des « déjà faits », mode ciblé par noms et `--all`, erreur sur nom inconnu listant les valides ; vérifier `setup.sh navigateurz` et le menu manuellement
- [ ] 3.5 Résumé final : table fait / déjà fait / sauté / échoué, section « Étapes manuelles restantes », chemin du journal en cas d'échec ; vérifier le rendu avec les modules factices
- [ ] 3.6 `shellcheck setup.sh` sans avertissement ; supprimer les modules factices de test (ou les garder sous `tests/fixtures/`)

## 4. Modules `base` et `1password`

- [ ] 4.1 `modules/00-base.sh` : `apt update && upgrade` (après `ui_confirm`, oui par défaut) puis paquets listés dans la spec ; vérifier dans la WSL que deux exécutions successives donnent « fait » puis « déjà fait »
- [ ] 4.2 `modules/10-1password.sh` — installation : dépôt officiel + `debsig`, `1password-cli` toujours, `1password` si `has_gui` ; vérifier dans la WSL que seul le CLI est installé et que `op --version` fonctionne
- [ ] 4.3 `modules/10-1password.sh` — connexion : `op whoami`, parcours « intégration app » (guidage + confirmation) et parcours `op account add` / `op signin` avec export de session ; vérifier dans la WSL le parcours manuel jusqu'à `op whoami` réussi
- [ ] 4.4 `modules/10-1password.sh` — agent SSH : ligne `SSH_AUTH_SOCK` idempotente dans la config shell commune quand l'app est installée, `manual_step` pour l'activation ; vérifier que deux exécutions ne dupliquent pas la ligne

## 5. Bootstrap et test de bout en bout

- [ ] 5.1 `bootstrap.sh` : `apt install git gum` si absents, clone HTTPS ou `git pull`, refus si `~/dotfiles` n'est pas un dépôt, `exec bash setup.sh < /dev/tty` ; `shellcheck` propre et vérifier localement `bash bootstrap.sh` avec un `~/dotfiles` déjà cloné (parcours `git pull`)
- [ ] 5.2 Pousser `main` sur le dépôt GitHub `JAPellerin/dotfiles-imarcom` (créé, vide, remote SSH `git@github.com:JAPellerin/dotfiles-imarcom.git`), avec les URL raw + clone HTTPS en constantes dans `bootstrap.sh` ; vérifier `curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | head -1` renvoie le shebang
- [ ] 5.3 Créer la VM Hyper-V Ubuntu 26.04 Desktop et prendre un snapshot « vierge » ; vérifier que le snapshot se restaure
- [ ] 5.4 Test de bout en bout dans la VM : `curl -fsSL <url-raw>/bootstrap.sh | bash` → menu → `base` + `1password` (app + CLI, intégration, agent SSH) ; vérifier le résumé final, `op whoami`, `echo $SSH_AUTH_SOCK` dans un nouveau shell, puis restaurer le snapshot et relancer pour vérifier l'idempotence (« déjà fait » partout)
