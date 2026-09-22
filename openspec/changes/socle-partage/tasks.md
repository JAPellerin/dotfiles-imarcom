## 1. Fragments de configuration shell

- [x] 1.1 `lib/core.sh` : ajouter `SHELL_COMMON_RC_DIR="${SHELL_COMMON_RC_DIR:-$HOME/.commonrc.d}"` à côté de `SHELL_COMMON_RC`, avec le commentaire renvoyant à la convention (D3) ; vérifier `shellcheck lib/core.sh` propre et `bash -c 'source lib/core.sh; echo $SHELL_COMMON_RC_DIR'`
- [x] 1.2 `config/shell/commonrc` : ajouter en fin de fichier la boucle POSIX de chargement des fragments (D1) ; vérifier `shellcheck config/shell/commonrc` propre, puis, avec un `~/.commonrc.d/zz-essai.sh` temporaire, que `bash -ic 'echo $ESSAI'` et `zsh -ic 'echo $ESSAI'` l'affichent, et qu'après suppression du dossier les deux shells démarrent sans message
- [x] 1.3 `tests/test-shell.sh` : ajouter les deux cas de D6 (fragment vu par bash et zsh et surchargeant une valeur de `commonrc` ; dossier absent → aucun message sur la sortie d'erreur) ; vérifier `bash tests/test-shell.sh` vert

## 2. Helper `.deb` depuis une URL

- [x] 2.1 `lib/apt.sh` : `apt_install_deb_url <url> <paquet>` selon D4 (garde `pkg_installed`, `mktemp -d` + `add_cleanup`, `curl -fsSL`, contrôle `dpkg-deb --info`, `apt_update_once`, `apt-get install` du chemin absolu sous `ui_spin`), commentaire d'en-tête dans le style des helpers voisins ; vérifier `shellcheck lib/apt.sh` propre
- [x] 2.2 `tests/test-apt.sh` : les quatre cas de D6 avec un `.deb` construit par `dpkg-deb --build` et servi en `file://` (déjà installé → aucun appel ; installation → un `apt-get install` avec le chemin du fichier ; fichier non-`.deb` → échec sans `apt-get` ; URL absente → échec nommant l'URL, temporaire nettoyé) ; vérifier `bash tests/test-apt.sh` vert

## 3. Helper de police

- [x] 3.1 `lib/fonts.sh` : nouveau fichier avec `FONTS_DIR` surchargeable et `install_font <url> <famille> [dossier]` selon D5 (appoint `fontconfig`, garde `fc-list`, extraction en temporaire puis copie des `*.ttf`/`*.otf`, `fc-cache -f`, re-vérification) ; le charger dans `setup.sh` à la suite des autres fichiers de `lib/` ; vérifier `shellcheck lib/fonts.sh setup.sh` propre et `./setup.sh --list` inchangé
- [x] 3.2 `tests/test-fonts.sh` : nouveau, `FONTS_DIR` dans `$TEST_TMP`, doublures `fc-list`/`fc-cache`, archive `.zip` fabriquée sur place, servie en `file://` ; les trois cas de D6 (première installation → fichiers sous `FONTS_DIR` et cache rafraîchi ; famille déjà connue → aucun téléchargement ; archive illisible → échec et aucun dossier de police laissé) ; vérifier `bash tests/test-fonts.sh` vert

## 4. Vérification d'ensemble et documentation

- [ ] 4.1 Lint et tests complets : ajouter `config/*/commonrc.sh` à la ligne `shellcheck` de `CLAUDE.md` (motif pour les fragments à venir, D7/Risks) ; vérifier `shellcheck setup.sh bootstrap.sh lib/*.sh modules/*.sh tests/*.sh tests/fixtures/*/*.sh config/shell/commonrc config/shell/bashrc-extra.sh` sans avertissement et `bash tests/run-all.sh` vert
- [ ] 4.2 Exécution réelle dans la WSL : `git pull` puis, dans un nouveau terminal, vérifier que `~/.commonrc` (lien vers le dépôt) charge bien un fragment d'essai déposé à la main dans `~/.commonrc.d`, puis le retirer ; `./setup.sh shell` → « déjà fait » (le module n'a pas changé) ; `./setup.sh --list` inchangé
- [ ] 4.3 `CLAUDE.md` : mentionner `~/.commonrc.d/` comme point d'extension de la config shell commune (un fragment `config/<module>/commonrc.sh` par module, `commonrc` n'est plus édité par un module) et les deux nouveaux helpers dans la liste des helpers de `lib/` ; `ROADMAP.md` : vague 0 faite ; `openspec validate socle-partage --strict` vert
